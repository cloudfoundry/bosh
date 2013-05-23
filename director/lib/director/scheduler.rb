require 'rufus/scheduler'

module Bosh::Director
  class Scheduler

    class UnknownCommand < StandardError; end

    attr_reader :scheduler

    def initialize(scheduled_jobs=[])
      @scheduled_jobs = scheduled_jobs
    end

    def scheduler
      @scheduler ||= Rufus::Scheduler::PlainScheduler.new
    end

    def logger
      @logger ||= Config.logger
    end

    def cloud
      @cloud ||= Config.cloud
    end

    def snapshot_manager
      @snapshot_manger ||= Bosh::Director::Api::SnapshotManager.new
    end

    def add_jobs
      @scheduled_jobs.each do |scheduled_job|
        command = scheduled_job['command'].to_s
        schedule = scheduled_job['schedule']
        raise "unknown command scheduled job `#{command}'" unless respond_to? command
        scheduler.cron(schedule) do |job|
          self.send(command.to_sym)
          logger.info("ran `#{command}', next run at `#{job.next_time}'")
        end
        logger.info("added scheduled job `#{command}' with interval '#{schedule}'")
      end
    end

    def start!
      logger.info('starting scheduler')
      add_jobs if scheduler.cron_jobs.empty?
      scheduler.start
      scheduler.join
    end

    def stop!
      logger.info('stopping scheduler')
      scheduler.stop
    end

    def snapshot_deployments
      logger.info('starting snapshots of deployments')

      Bosh::Director::Models::Deployment.all do |deployment|
        snapshot_manager.create_deployment_snapshot_task('scheduler', deployment)
      end
    end

    def snapshot_self
      logger.info('starting self_snapshot')
      vm_id = cloud.current_vm_id
      disks = cloud.get_disks(vm_id)
      metadata = {
          deployment: 'self',
          job: 'director',
          index: 0,
          director_name: Config.name,
          director_uuid: Config.uuid,
          agent_id: 'self',
          instance_id: vm_id
      }

      disks.each { |disk| cloud.snapshot_disk(disk, metadata) }
    end
  end
end