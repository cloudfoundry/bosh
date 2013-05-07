require 'rufus/scheduler'

module Bosh::Director
  class Scheduler

    class UnknownCommand < StandardError; end

    attr_reader :scheduler

    COMMANDS = %w[snapshot_deployments]

    def initialize(scheduled_jobs=[])
      @scheduled_jobs = scheduled_jobs
    end

    def scheduler
      @scheduler ||= Rufus::Scheduler::PlainScheduler.new
    end

    def logger
      @logger ||= Config.logger
    end

    def add_jobs
      @scheduled_jobs.each do |scheduled_job|
        command = scheduled_job['command'].to_s
        schedule = scheduled_job['schedule']
        raise "unknown command scheduled job `#{command}'" unless COMMANDS.include?(command)
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
      logger.info('starting snapshots')
      snapshot_manager ||= Bosh::Director::Api::SnapshotManager.new
      Bosh::Director::Models::Deployment.all do |deployment|
        snapshot_manager.create_deployment_snapshot_task('scheduler', deployment)
      end
      #TODO track task and alert/log if failed
    end
  end
end