module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateStep
        def initialize(base_job, event_log, resource_pools, deployment_plan, multi_job_updater, cloud, blobstore)
          @base_job = base_job
          @logger = base_job.logger
          @event_log = event_log
          @resource_pools = resource_pools
          @cloud = cloud
          @blobstore = blobstore
          @deployment_plan = deployment_plan
          @multi_job_updater = multi_job_updater
        end


        def perform
          begin
            @logger.info('Updating deployment')
            assemble
            update_jobs
            @logger.info('Committing updates')
            @deployment_plan.persist_updates!
            @logger.info('Finished updating deployment')
          ensure
            @deployment_plan.update_stemcell_references!
          end
        end

        private

        def assemble
          @logger.info('Deleting no longer needed VMs')
          delete_unneeded_vms

          @logger.info('Deleting no longer needed instances')
          delete_unneeded_instances

          @logger.info('Updating resource pools')
          @resource_pools.update
          @base_job.task_checkpoint

          @logger.info('Binding instance VMs')
          bind_instance_vms

          @event_log.begin_stage('Preparing configuration', 1)
          @base_job.track_and_log('Binding configuration') do
            bind_configuration
          end
        end

        def update_jobs
          @logger.info('Updating jobs')
          @multi_job_updater.run(
            @base_job,
            @deployment_plan,
            @deployment_plan.jobs_starting_on_deploy,
          )

          @logger.info('Refilling resource pools')
          @resource_pools.refill
        end

        private

        def bind_instance_vms
          jobs = @deployment_plan.jobs_starting_on_deploy
          instances = jobs.map(&:instances).flatten

          binder = DeploymentPlan::InstanceVmBinder.new(@event_log)
          binder.bind_instance_vms(instances)
        end

        def delete_unneeded_vms
          unneeded_vms = @deployment_plan.unneeded_vms
          if unneeded_vms.empty?
            @logger.info('No unneeded vms to delete')
            return
          end

          @event_log.begin_stage('Deleting unneeded VMs', unneeded_vms.size)
          ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
            unneeded_vms.each do |vm_model|
              pool.process do
                @event_log.track(vm_model.cid) do
                  @logger.info("Delete unneeded VM #{vm_model.cid}")
                  @cloud.delete_vm(vm_model.cid)
                  vm_model.destroy
                end
              end
            end
          end
        end

        def delete_unneeded_instances
          unneeded_instances = @deployment_plan.unneeded_instances
          if unneeded_instances.empty?
            @logger.info('No unneeded instances to delete')
            return
          end

          event_log_stage = @event_log.begin_stage('Deleting unneeded instances', unneeded_instances.size)
          instance_deleter = InstanceDeleter.new(@deployment_plan)
          instance_deleter.delete_instances(unneeded_instances, event_log_stage)
          @logger.info('Deleted no longer needed instances')
        end

        # Calculates configuration checksums for all jobs in this deployment plan
        # @return [void]
        def bind_configuration
          @deployment_plan.jobs_starting_on_deploy.each do |job|
            JobRenderer.new(job, @blobstore).render_job_instances
          end
        end
      end
    end
  end
end
