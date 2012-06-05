# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob

      @queue = :normal

      # @param [String] manifest_file Path to deployment manifest
      # @param [Hash] options Deployment options
      def initialize(manifest_file, options = {})
        super

        logger.info("Reading deployment manifest")
        @manifest_file = manifest_file
        @manifest = File.read(@manifest_file)
        logger.debug("Manifest:\n#{@manifest}")

        logger.info("Creating deployment plan")
        logger.info("Deployment plan options: #{options.pretty_inspect}")

        plan_options = {
          "recreate" => !!options["recreate"],
          "job_states" => options["job_states"] || {},
          "job_rename" => options["job_rename"] || {}
        }

        manifest_as_hash = YAML.load(@manifest)
        @deployment_plan = DeploymentPlan.new(manifest_as_hash, plan_options)
        logger.info("Created deployment plan")

        resource_pools = @deployment_plan.resource_pools
        @resource_pool_updaters = resource_pools.map do |resource_pool|
          ResourcePoolUpdater.new(resource_pool)
        end
      end

      def prepare
        @deployment_plan_compiler = DeploymentPlanCompiler.new(@deployment_plan)
        event_log.begin_stage("Preparing deployment", 8)

        track_and_log("Binding deployment") do
          @deployment_plan_compiler.bind_deployment
        end

        track_and_log("Binding releases") do
          @deployment_plan_compiler.bind_releases
        end

        track_and_log("Binding existing deployment") do
          @deployment_plan_compiler.bind_existing_deployment
        end

        track_and_log("Binding resource pools") do
          @deployment_plan_compiler.bind_resource_pools
        end

        track_and_log("Binding stemcells") do
          @deployment_plan_compiler.bind_stemcells
        end

        track_and_log("Binding templates") do
          @deployment_plan_compiler.bind_templates
        end

        track_and_log("Binding unallocated VMs") do
          @deployment_plan_compiler.bind_unallocated_vms
        end

        track_and_log("Binding instance networks") do
          @deployment_plan_compiler.bind_instance_networks
        end

        logger.info("Compiling and binding packages")
        PackageCompiler.new(@deployment_plan).compile
      end

      def update_resource_pools
        ThreadPool.new(:max_threads => 32).wrap do |thread_pool|
          # Delete extra VMs across resource pools
          event_log.begin_stage("Deleting extra VMs",
                                sum_across_pools(:extra_vm_count))
          @resource_pool_updaters.each do |updater|
            updater.delete_extra_vms(thread_pool)
          end
          thread_pool.wait

          # Delete outdated idle vms across resource pools, outdated allocated
          # VMs are handled by instance updater
          event_log.begin_stage("Deleting outdated idle VMs",
                                sum_across_pools(:outdated_idle_vm_count))

          @resource_pool_updaters.each do |updater|
            updater.delete_outdated_idle_vms(thread_pool)
          end
          thread_pool.wait

          # Create missing VMs across resource pools phase 1:
          # only creates VMs that have been bound to instances
          # to avoid refilling the resource pool before instances
          # that are no longer needed have been deleted.
          event_log.begin_stage("Creating bound missing VMs",
                                sum_across_pools(:bound_missing_vm_count))
          @resource_pool_updaters.each do |updater|
            updater.create_bound_missing_vms(thread_pool)
          end
        end
      end

      def refill_resource_pools
        # Instance updaters might have added some idle vms
        # so they can be returned to resource pool. In that case
        # we need to pre-allocate network settings for all of them.
        @resource_pool_updaters.each do |resource_pool_updater|
          resource_pool_updater.reserve_networks
        end

        event_log.begin_stage("Refilling resource pools",
                              sum_across_pools(:missing_vm_count))
        ThreadPool.new(:max_threads => 32).wrap do |thread_pool|
          # Create missing VMs across resource pools phase 2:
          # should be called after all instance updaters are finished to
          # create additional VMs in order to balance resource pools
          @resource_pool_updaters.each do |resource_pool_updater|
            resource_pool_updater.create_missing_vms(thread_pool)
          end
        end
      end

      def update
        event_log.begin_stage("Preparing DNS", 1)
        track_and_log("Binding DNS") do
          if Config.dns_enabled?
            @deployment_plan_compiler.bind_dns
          end
        end

        logger.info("Updating resource pools")
        update_resource_pools
        task_checkpoint

        logger.info("Binding instance VMs")
        @deployment_plan_compiler.bind_instance_vms

        event_log.begin_stage("Preparing configuration", 1)
        track_and_log("Binding configuration") do
          @deployment_plan_compiler.bind_configuration
        end

        logger.info("Deleting no longer needed VMs")
        @deployment_plan_compiler.delete_unneeded_vms

        logger.info("Deleting no longer needed instances")
        @deployment_plan_compiler.delete_unneeded_instances

        logger.info("Updating jobs")
        @deployment_plan.jobs.each do |job|
          task_checkpoint
          logger.info("Updating job: #{job.name}")
          JobUpdater.new(@deployment_plan, job).update
        end

        logger.info("Refilling resource pools")
        refill_resource_pools
      end

      def update_stemcell_references
        current_stemcells = Set.new
        @deployment_plan.resource_pools.each do |resource_pool|
          current_stemcells << resource_pool.stemcell.stemcell
        end

        deployment = @deployment_plan.deployment
        stemcells = deployment.stemcells
        stemcells.each do |stemcell|
          unless current_stemcells.include?(stemcell)
            stemcell.remove_deployment(deployment)
          end
        end
      end

      def perform
        with_deployment_lock do
          with_release_locks do
            logger.info("Preparing deployment")
            prepare
            begin
              deployment = @deployment_plan.deployment
              logger.info("Finished preparing deployment")
              logger.info("Updating deployment")
              update

              deployment.db.transaction do
                deployment.remove_all_releases
                deployment.remove_all_release_versions
                # Now we know that deployment has succeeded and can remove
                # previous partial deployments release version references
                # to be able to delete these release versions later.
                @deployment_plan.releases.each do |release|
                  deployment.add_release(release.release)
                  deployment.add_release_version(release.release_version)
                end
              end

              deployment.manifest = @manifest
              deployment.save
              logger.info("Finished updating deployment")
              "/deployments/#{deployment.name}"
            ensure
              update_stemcell_references
            end
          end
        end
      ensure
        FileUtils.rm_rf(@manifest_file)
      end

      private

      def with_deployment_lock
        name = @deployment_plan.name
        logger.info("Acquiring deployment lock on #{name}")
        Lock.new("lock:deployment:#{name}").lock { yield }
      end

      def with_release_locks
        release_names = @deployment_plan.releases.map do |release|
          release.name
        end

        # Sorting to enforce lock order to avoid deadlocks
        locks = release_names.sort.map do |release_name|
          logger.info("Acquiring release lock: #{release_name}")
          Lock.new("lock:release:#{release_name}")
        end

        begin
          locks.each { |lock| lock.lock }
          yield
        ensure
          locks.reverse_each { |lock| lock.release }
        end
      end

      def sum_across_pools(counting_method)
        @resource_pool_updaters.inject(0) do |sum, updater|
          sum + updater.send(counting_method.to_sym)
        end
      end

    end
  end
end
