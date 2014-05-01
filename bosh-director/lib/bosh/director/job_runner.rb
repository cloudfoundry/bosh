# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class JobRunner

    # @param [Class] job_class Job class to instantiate and run
    # @param [Integer] task_id Existing task id
    def initialize(job_class, task_id)
      unless job_class.kind_of?(Class) &&
        job_class <= Jobs::BaseJob
        raise DirectorError, "Invalid director job class `#{job_class}'"
      end

      @task_id = task_id
      setup_task_logging

      task_manager = Bosh::Director::Api::TaskManager.new

      @job_class = job_class
      @task_logger.info("Looking for task with task id #{@task_id}")
      @task = task_manager.find_task(@task_id)
    end

    # Runs director job
    def run(*args)
      Config.current_job = nil

      @task_logger.info("Starting task: #{@task_id}")
      started_at = Time.now

      with_thread_name("task:#{@task_id}") { perform_job(*args) }

      duration = Duration.duration(Time.now - started_at)
      @task_logger.info("Task took #{duration} to process.")
    end

    # Task checkpoint: updates timestamp so running task isn't marked as
    # timed out.
    # @return [void]
    def checkpoint
      @task.update(:checkpoint_time => Time.now)
    end

    private

    # Sets up job logging.
    # @return [void]
    def setup_task_logging
      log_dir = File.join(Config.base_dir, 'tasks', @task_id.to_s)
      FileUtils.mkdir_p(log_dir)

      debug_log = File.join(log_dir, 'debug')
      event_log = File.join(log_dir, 'event')
      result_log = File.join(log_dir, 'result')

      @task_logger = Logger.new(debug_log)
      @task_logger.level = Config.logger.level
      @task_logger.formatter = ThreadFormatter.new

      Config.event_log = EventLog::Log.new(event_log)
      Config.result = TaskResultFile.new(result_log)
      Config.logger = @task_logger

      Config.db.logger = @task_logger

      if Config.dns_enabled?
        Config.dns_db.logger = @task_logger
      end

      cpi_log = File.join(log_dir, 'cpi')
      Config.cloud_options['properties'] ||= {}
      Config.cloud_options['properties']['cpi_log'] = cpi_log
    end

    # Instantiates and performs director job.
    # @param [Array] args Opaque list of job arguments that will be used to
    #   instantiate the new job object.
    # @return [void]
    def perform_job(*args)
      @task_logger.info('Creating job')

      job = @job_class.new(*args)
      Config.current_job = job

      job.task_id = @task_id
      job.task_checkpoint # cancelled in the queue?

      run_checkpointing

      @task_logger.info("Performing task: #{@task.id}")

      @task.state = :processing
      @task.timestamp = Time.now
      @task.checkpoint_time = Time.now
      @task.save

      result = job.perform

      @task_logger.info('Done')
      finish_task(:done, result)

    rescue Bosh::Director::TaskCancelled => e
      log_exception(e)
      @task_logger.info("Task #{@task.id} cancelled")
      finish_task(:cancelled, 'task cancelled')
    rescue Exception => e
      log_exception(e)
      @task_logger.error("#{e}\n#{e.backtrace.join("\n")}")
      finish_task(:error, e)
    end

    # Spawns a thread that periodically updates task checkpoint time.
    # There is no need to kill this thread as job execution lifetime is the
    # same as Resque worker process lifetime.
    # @return [Thread] Checkpoint thread
    def run_checkpointing
      Thread.new do
        with_thread_name("task:#{@task.id}-checkpoint") do
          while true
            sleep(Config.task_checkpoint_interval)
            checkpoint
          end
        end
      end
    end

    # Truncates string to fit task result length
    # @param [String] string The original string
    # @param [Integer] len Desired string length
    # @return [String] Truncated string
    def truncate(string, len = 128)
      stripped = string.strip[0..len]
      if stripped.length > len
        stripped.gsub(/\s+?(\S+)?$/, "") + "..."
      else
        stripped
      end
    end

    # Marks task completion
    # @param [Symbol] state Task completion state
    # @param [#to_s] result
    def finish_task(state, result)
      @task.state = state
      @task.result = truncate(result.to_s)
      @task.timestamp = Time.now
      @task.save
    end

    # Logs the exception in the event log
    # @param [Exception] exception
    def log_exception(exception)
      # Event log is being used here to propagate the error.
      # It's up to event log renderer to find the error and
      # signal it properly.
      director_error = DirectorError.create_from_exception(exception)
      Config.event_log.log_error(director_error)
    end

  end
end
