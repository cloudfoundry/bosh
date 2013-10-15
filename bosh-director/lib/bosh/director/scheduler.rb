require 'rufus/scheduler'

module Bosh::Director
  class Scheduler
    def initialize(scheduled_jobs=[], options={})
      if scheduled_jobs.nil? || scheduled_jobs.is_a?(Array)
        @scheduled_jobs = scheduled_jobs
        @scheduler = options.fetch(:scheduler) { Rufus::Scheduler::PlainScheduler.new }
        @queue = options.fetch(:queue) { JobQueue.new }
      else
        raise 'scheduled_jobs must be an array'
      end
    end

    def start!
      logger.info('starting scheduler')
      add_jobs unless @added_already
      @scheduler.start
      @scheduler.join
    end

    def stop!
      logger.info('stopping scheduler')
      @scheduler.stop
    end

    def logger
      @logger ||= Config.logger
    end

    private

    def add_jobs
      return if @scheduled_jobs.nil?
      @added_already = true

      @scheduled_jobs.each do |scheduled_job|
        begin
          director_job_class = Bosh::Director::Jobs.const_get(scheduled_job['command'].to_s)
        rescue NameError
          raise "unknown job `Bosh::Director::Jobs::#{scheduled_job['command']}'"
        end

        @scheduler.cron(scheduled_job['schedule']) do |_|
          logger.info("enqueueing `#{scheduled_job['command']}'")

          @queue.enqueue('scheduler',
                         director_job_class,
                         "scheduled #{scheduled_job['command']}",
                         scheduled_job['params'])
        end

        logger.info("added scheduled job `#{director_job_class}' with interval '#{scheduled_job['schedule']}'")
      end
    end
  end
end