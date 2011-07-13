module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob

      @queue = :normal

      def initialize(manifest_file, options = {})
        @logger = Config.logger
        @event_log = Config.event_logger
        @logger.info("Reading deployment manifest")
        @manifest_file = manifest_file
        @manifest = File.open(@manifest_file) { |f| f.read }
        @logger.debug("Manifest:\n#{@manifest}")
        @logger.info("Creating deployment plan")

        @logger.info("Deployment plan options: #{options.pretty_inspect}")

        plan_options = {
          "recreate"   => !!options["recreate"],
          "job_states" => options["job_states"] || { }
        }

        @deployment_plan = DeploymentPlan.new(YAML.load(@manifest), plan_options)
        @logger.info("Created deployment plan")

        @resource_pool_updaters = @deployment_plan.resource_pools.map do |resource_pool|
          ResourcePoolUpdater.new(resource_pool)
        end
      end

      def prepare
        @logger.info("Looking up deployment record")
        @deployment_plan.deployment = Models::Deployment.find_or_create(:name => @deployment_plan.name)
        @deployment_plan_compiler = DeploymentPlanCompiler.new(@deployment_plan)

        progress_and_log("Preparing", "Binding release", 0, 9)
        @deployment_plan_compiler.bind_release
        progress_and_log("Preparing", "Binding existing deployment", 1, 9)
        @deployment_plan_compiler.bind_existing_deployment
        progress_and_log("Preparing", "Binding resource pools", 2, 9)
        @deployment_plan_compiler.bind_resource_pools
        progress_and_log("Preparing", "Binding stemcells", 3, 9)
        @deployment_plan_compiler.bind_stemcells
        progress_and_log("Preparing", "Binding templates", 4, 9)
        @deployment_plan_compiler.bind_templates
        progress_and_log("Preparing", "Binding unallocated VMs", 5, 9)
        @deployment_plan_compiler.bind_unallocated_vms
        progress_and_log("Preparing", "Binding instance networks", 6, 9)
        @deployment_plan_compiler.bind_instance_networks
        progress_and_log("Preparing", "Compiling and binding packages", 7, 9)
        PackageCompiler.new(@deployment_plan).compile
        progress_and_log("Preparing", "Binding configuration", 8, 9)
        @deployment_plan_compiler.bind_configuration
      end

      def update_resource_pools
        resource_pool_updaters = []
        ThreadPool.new(:max_threads => 32).wrap do |thread_pool|
          # delete extra VMs across resource pools
          @resource_pool_updaters.each do |resource_pool_updater|
            resource_pool_updater.delete_extra_vms(thread_pool)
          end
          thread_pool.wait

          # delete outdated VMs across resource pools
          @resource_pool_updaters.each do |resource_pool_updater|
            resource_pool_updater.delete_outdated_vms(thread_pool)
          end
          thread_pool.wait

          # create missing VMs across resource pools phase 1:
          # only creates VMs that have been bound to instances
          # to avoid refilling the resource pool before instances
          # that are no longer needed have been deleted.
          @resource_pool_updaters.each do |resource_pool_updater|
            resource_pool_updater.create_bound_missing_vms(thread_pool)
          end
        end
      end

      def refill_resource_pools
        # Instance updaters might have added some idle vms
        # so they can be returned to resource pool. In that case
        # we need to pre-allocate network settings for all of them.
        @resource_pool_updaters.each do |resource_pool_updater|
          resource_pool_updater.allocate_dynamic_ips
        end

        ThreadPool.new(:max_threads => 32).wrap do |thread_pool|
          # create missing VMs across resource pools phase 2:
          # should be called after all instance updaters are finished to
          # create additional VMs in order to balance resource pools
          @resource_pool_updaters.each do |resource_pool_updater|
            resource_pool_updater.create_missing_vms(thread_pool)
          end
        end
      end

      def update
        @logger.info("Updating resource pools")
        update_resource_pools
        cancel_checkpoint

        @logger.info("Binding instance VMs")
        @deployment_plan_compiler.bind_instance_vms

        @logger.info("Deleting no longer needed VMs")
        @deployment_plan_compiler.delete_unneeded_vms

        @logger.info("Deleting no longer needed instances")
        @deployment_plan_compiler.delete_unneeded_instances

        @logger.info("Updating jobs")
        @deployment_plan.jobs.each do |job|
          cancel_checkpoint
          @logger.info("Updating job: #{job.name}")
          JobUpdater.new(job).update
        end

        @logger.info("Refilling resource pools")
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
        @logger.info("Acquiring deployment lock: #{@deployment_plan.name}")
        deployment_lock = Lock.new("lock:deployment:#{@deployment_plan.name}")
        deployment_lock.lock do
          @logger.info("Acquiring release lock: #{@deployment_plan.release.name}")
          release_lock = Lock.new("lock:release:#{@deployment_plan.release.name}")
          release_lock.lock do
            @logger.info("Preparing deployment")
            prepare
            begin
              deployment = @deployment_plan.deployment
              @logger.info("Finished preparing deployment")
              @logger.info("Updating deployment")
              update

              # Now we know that deployment has succeded and can remove
              # previous partial deployments release version references
              # to be able to delete these release versions later.
              deployment.db.transaction do
                deployment.remove_all_release_versions
                deployment.add_release_version(@deployment_plan.release.release_version)
              end

              deployment.manifest = @manifest
              deployment.save
              @logger.info("Finished updating deployment")
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
      def progress_and_log(stage, msg, current, total)
        @event_log.progress_log(stage, msg, current, total)
        @logger.info(msg)
      end
    end
  end
end
