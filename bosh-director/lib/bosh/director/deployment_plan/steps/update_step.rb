module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateStep
        def initialize(base_job, deployment_plan, multi_job_updater, cloud)
          @base_job = base_job
          @logger = base_job.logger
          @cloud = cloud
          @deployment_plan = deployment_plan
          @multi_job_updater = multi_job_updater
          @disk_manager = DiskManager.new(@cloud, @logger)
          @dns_manager = DnsManagerProvider.create
          job_renderer = JobRenderer.create
          agent_broadcaster = AgentBroadcaster.new
          @vm_deleter = Bosh::Director::VmDeleter.new(@cloud, @logger, false, Config.enable_virtual_delete_vms)
          @vm_creator = Bosh::Director::VmCreator.new(@cloud, @logger, @vm_deleter, @disk_manager, job_renderer, agent_broadcaster)
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
          @logger.info('Deleting no longer needed instances')
          delete_unneeded_instances

          @logger.info('Creating missing VMs')
          # TODO: something about instance_plans.select(&:new?) -- how does that compare to the isntance#has_vm? check?
          @vm_creator.create_for_instance_plans(@deployment_plan.instance_plans_with_missing_vms, @deployment_plan.ip_provider, @deployment_plan.tags)

          @base_job.task_checkpoint
        end

        def update_jobs
          @logger.info('Updating instances')
          @multi_job_updater.run(
            @base_job,
            @deployment_plan,
            @deployment_plan.instance_groups_starting_on_deploy,
          )
        end

        def delete_unneeded_instances
          unneeded_instance_plans = @deployment_plan.unneeded_instance_plans
          if unneeded_instance_plans.empty?
            @logger.info('No unneeded instances to delete')
            return
          end
          event_log_stage = Config.event_log.begin_stage('Deleting unneeded instances', unneeded_instance_plans.size)
          instance_deleter = InstanceDeleter.new(@deployment_plan.ip_provider, @dns_manager, @disk_manager)
          instance_deleter.delete_instance_plans(unneeded_instance_plans, event_log_stage)
          @logger.info('Deleted no longer needed instances')
        end
      end
    end
  end
end
