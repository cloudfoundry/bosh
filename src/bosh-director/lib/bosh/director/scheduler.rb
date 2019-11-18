require 'rufus/scheduler'

module Bosh::Director
  class Scheduler
    def initialize(scheduled_jobs = [], options = {})
      raise 'scheduled_jobs must be an array' if !scheduled_jobs.nil? && !scheduled_jobs.is_a?(Array)

      @scheduled_jobs = scheduled_jobs
      @scheduler = options.fetch(:scheduler) { Rufus::Scheduler.new }
      @queue = options.fetch(:queue) { JobQueue.new }
    end

    def start!
      logger.info('starting scheduler')
      add_jobs unless @added_already
      @scheduler.join
    end

    def stop!
      logger.info('stopping scheduler')
      @scheduler.shutdown
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
          raise "unknown job 'Bosh::Director::Jobs::#{scheduled_job['command']}'"
        end

        @scheduler.cron(scheduled_job['schedule']) do |_|
          should_enqueue = true

          if director_job_class.respond_to?(:has_work)
            logger.debug("Scheduler cron - checking /
#{director_job_class}.has_work:#{director_job_class.has_work(scheduled_job['params'])} /
with params #{scheduled_job['params']}")

            should_enqueue = director_job_class.has_work(scheduled_job['params'])
          end

          if should_enqueue
            logger.info("enqueueing '#{scheduled_job['command']}'")

            schedule_message = "scheduled #{scheduled_job['command']}"
            schedule_message = director_job_class.schedule_message if director_job_class.respond_to?(:schedule_message)

            @queue.enqueue(
              'scheduler',
              director_job_class,
              schedule_message,
              scheduled_job['params'],
            )
          end
        end

        logger.info("added scheduled job '#{director_job_class}' with interval '#{scheduled_job['schedule']}'")
      end
    end
  end
end
