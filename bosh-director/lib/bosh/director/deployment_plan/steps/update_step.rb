module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateStep
        def initialize(base_job, event_log, deployment_plan, multi_job_updater, cloud, blobstore)
          @base_job = base_job
          @logger = base_job.logger
          @event_log = event_log
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

          @logger.info('Creating missing VMs')
          create_missing_vms
          @base_job.task_checkpoint

          @logger.info('Binding instance VMs')
        end

        def update_jobs
          @logger.info('Updating jobs')
          @multi_job_updater.run(
            @base_job,
            @deployment_plan,
            @deployment_plan.jobs_starting_on_deploy,
          )
        end

        private

        def create_missing_vms
          instances_with_missing_vms = @deployment_plan.instances_with_missing_vms
          return @logger.info('No missing vms to create') if instances_with_missing_vms.empty?
          counter = instances_with_missing_vms.length
          ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
            instances_with_missing_vms.each do |instance|
              pool.process do
                @event_log.track("#{instance.job.name}/#{instance.index}") do
                  with_thread_name("create_missing_vm(#{instance.job.name}, #{instance.index}/#{counter})") do
                    @logger.info("Creating missing VM #{instance.job.name} #{instance.index}")
                    disks = [instance.model.persistent_disk_cid]
                    Bosh::Director::VmCreator.create_for_instance(instance,disks)
                  end
                end
              end
            end
          end
        end

        def delete_unneeded_vms
          unneeded_vms = @deployment_plan.unneeded_vms
          return @logger.info('No unneeded vms to delete') if unneeded_vms.empty?

          @event_log.begin_stage('Deleting unneeded VMs', unneeded_vms.size)
          ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
            unneeded_vms.each do |vm_model,reservations_by_network|
              pool.process do
                @event_log.track(vm_model.cid) do
                  @logger.info("Delete unneeded VM #{vm_model.cid}")
                  @cloud.delete_vm(vm_model.cid)
                  reservations_by_network.each do |network_name,reservation|
                      @deployment_plan.network(network_name).release(reservation)
                  end
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
      end
    end
  end
end
