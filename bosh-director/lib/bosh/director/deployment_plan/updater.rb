module Bosh::Director
  module DeploymentPlan
    class Updater
      def initialize(job, event_log, resource_pools, assembler, deployment_plan)
        @job = job
        @logger = job.logger
        @event_log = event_log
        @resource_pools = resource_pools
        @assembler = assembler
        @deployment_plan = deployment_plan
      end

      def update
        event_log.begin_stage('Preparing DNS', 1)
        job.track_and_log('Binding DNS') do
          if Config.dns_enabled?
            assembler.bind_dns
          end
        end

        logger.info('Updating resource pools')
        resource_pools.update
        job.task_checkpoint

        logger.info('Binding instance VMs')
        assembler.bind_instance_vms

        event_log.begin_stage('Preparing configuration', 1)
        job.track_and_log('Binding configuration') do
          assembler.bind_configuration
        end

        logger.info('Deleting no longer needed VMs')
        assembler.delete_unneeded_vms

        logger.info('Deleting no longer needed instances')
        assembler.delete_unneeded_instances

        logger.info('Updating jobs')
        deployment_plan.jobs.each do |bosh_job|
          job.task_checkpoint
          logger.info("Updating job: #{bosh_job.name}")
          JobUpdater.new(deployment_plan, bosh_job).update
        end

        logger.info('Refilling resource pools')
        resource_pools.refill
      end

      private

      attr_reader :job, :event_log, :resource_pools, :logger, :assembler, :deployment_plan
    end
  end
end
