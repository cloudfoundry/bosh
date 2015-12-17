module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateStep
        def initialize(base_job, event_log, deployment_plan, multi_job_updater, cloud)
          @base_job = base_job
          @logger = base_job.logger
          @event_log = event_log
          @cloud = cloud
          @deployment_plan = deployment_plan
          @multi_job_updater = multi_job_updater
          @vm_deleter = Bosh::Director::VmDeleter.new(@cloud, @logger)
          @disk_manager = DiskManager.new(@cloud, @logger)
          job_renderer = JobRenderer.create
          @vm_creator = Bosh::Director::VmCreator.new(@cloud, @logger, @vm_deleter, @disk_manager, job_renderer)
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
          # TODO: something about instance_plans.select(&:new?) -- how does that compare to the isntance#has_vm? check?
          @vm_creator.create_for_instance_plans(@deployment_plan.instance_plans_with_missing_vms, @deployment_plan.ip_provider, @event_log)

          @base_job.task_checkpoint
        end

        def update_jobs
          @logger.info('Updating jobs')
          @multi_job_updater.run(
            @base_job,
            @deployment_plan,
            @deployment_plan.jobs_starting_on_deploy,
          )
        end

        def delete_unneeded_vms
          unneeded_vms = @deployment_plan.unneeded_vms
          return @logger.info('No unneeded vms to delete') if unneeded_vms.empty?

          @event_log.begin_stage('Deleting unneeded VMs', unneeded_vms.size)
          ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
            unneeded_vms.each do |vm_model|
              pool.process do
                @event_log.track(vm_model.cid) do
                  @logger.info("Delete unneeded VM #{vm_model.cid}")
                  @vm_deleter.delete_vm(vm_model)
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
          dns_manager = DnsManager.create
          instance_deleter = InstanceDeleter.new(@deployment_plan.ip_provider, dns_manager, @disk_manager)
          unneeded_instance_plans = unneeded_instances.map do |instance|
            DeploymentPlan::InstancePlan.new(
              existing_instance: instance,
              instance: nil,
              desired_instance: nil,
              network_plans: [],
              recreate_deployment: @deployment_plan.recreate
            )
          end
          instance_deleter.delete_instance_plans(unneeded_instance_plans, event_log_stage)
          @logger.info('Deleted no longer needed instances')
        end
      end
    end
  end
end
