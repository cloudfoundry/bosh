module Bosh::Director
  class JobRunner

    # @param [Class] job_class Job class to instantiate and run
    # @param [Integer] task_id Existing task id
    def initialize(job_class, task_id, worker_name)
      unless job_class.kind_of?(Class) &&
        job_class <= Jobs::BaseJob
        raise DirectorError, "Invalid director job class '#{job_class}'"
      end

      @task_id = task_id
      @worker_name = worker_name
      setup_task_logging_for_files
      task_manager = Bosh::Director::Api::TaskManager.new

      @job_class = job_class
      @task_logger.info("Looking for task with task id #{@task_id}")
      @task = task_manager.find_task(@task_id)
      setup_task_logging_for_db
      @task_logger.info("Found task #{@task.inspect}")
    end

    # Runs director job
    def run(*args)
      Config.current_job = nil

      @task_logger.info("Running from worker '#{@worker_name}' on #{Config.runtime['instance']} (#{Config.runtime['ip']})")
      @task_logger.info("Starting task: #{@task_id}")
      started_at = Time.now

      with_thread_name("task:#{@task_id}") { perform_job(*args) }

      duration = Duration.duration(Time.now - started_at)
      @task_logger.info("Task took #{duration} to process.")
    end

    private

    # Sets up job logging.
    # @return [void]
    def setup_task_logging_for_files
      log_dir = File.join(Config.base_dir, 'tasks', @task_id.to_s)
      FileUtils.mkdir_p(log_dir)

      debug_log = File.join(log_dir, 'debug')

      @task_logger = Logging::Logger.new('DirectorJobRunner')
      shared_appender = Logging.appenders.file(
        'DirectorJobRunnerFile',
        filename: debug_log,
        layout: ThreadFormatter.layout,
        filters: [Bosh::Director::RegexLoggingFilter.null_query_filter],
      )
      @task_logger.add_appenders(shared_appender)
      @task_logger.level = Config.logger.level

      Config.logger = @task_logger

      Config.db.logger = @task_logger

      cpi_log = File.join(log_dir, 'cpi')
      Config.cloud_options['properties'] ||= {}
      Config.cloud_options['properties']['cpi_log'] = cpi_log
    end

    # Sets up job logging.
    # @return [void]
    def setup_task_logging_for_db
      Config.event_log = EventLog::Log.new(TaskDBWriter.new(:event_output, @task.id))
      Config.result = TaskDBWriter.new(:result_output, @task.id)
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

      @task_logger.info("Performing task: #{@task.inspect}")

      @task.timestamp = Time.now
      @task.started_at = Time.now
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
    # same as worker process lifetime.
    # @return [Thread] Checkpoint thread
    def run_checkpointing
      # task check pointer is scoped to separate class to avoid
      # the secondary thread and main thread modifying the same @task
      # variable (and accidentally clobbering it in the process)
      task_checkpointer = TaskCheckPointer.new(@task.id)
      Thread.new do
        with_thread_name("task:#{@task.id}-checkpoint") do
          while true
            sleep(Config.task_checkpoint_interval)
            task_checkpointer.checkpoint
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
      @task.refresh
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

  class TaskCheckPointer
    def initialize(task_id)
      task_manager = Bosh::Director::Api::TaskManager.new
      @task = task_manager.find_task(task_id)
    end

    def checkpoint
      @task.update(:checkpoint_time => Time.now)
    end
  end
end
