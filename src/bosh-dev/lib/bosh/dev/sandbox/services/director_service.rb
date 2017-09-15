require 'bosh/dev/sandbox/database_migrator'

module Bosh::Dev::Sandbox
  class DirectorService

    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    DEFAULT_DIRECTOR_CONFIG = 'director_test.yml'
    DIRECTOR_CONF_TEMPLATE = File.join(ASSETS_DIR, 'director_test.yml.erb')

    DIRECTOR_PATH = File.expand_path('bosh-director', REPO_ROOT)

    def initialize(options, logger)
      @database = options[:database]
      @logger = logger
      @director_tmp_path = options[:director_tmp_path]
      @director_config = options[:director_config]
      @base_log_path = options[:base_log_path]

      log_location = "#{@base_log_path}.director.out"
      @process = Service.new(
        %W[bosh-director -c #{@director_config}],
        {output: log_location},
        @logger,
      )

      @connector = HTTPEndpointConnector.new('director', 'localhost', options[:director_port], '/info', "\"uuid\"", log_location, @logger)

      @worker_processes = 3.times.map do |index|
        Service.new(
          %W[bosh-director-worker -c #{@director_config} -i #{index}],
          {output: "#{@base_log_path}.worker_#{index}.out", env: {'QUEUE' => 'normal,urgent'}},
          @logger,
        )
      end

      @database_migrator = DatabaseMigrator.new(DIRECTOR_PATH, @director_config, @logger)
    end

    def start(config, force_migration = false)
      write_config(config)

      migrate_database(force_migration)

      reset

      @process.start

      start_workers

      begin
        # CI does not have enough time to start bosh-director
        # for some parallel tests; increasing to 60 secs (= 300 tries).
        @connector.try_to_connect(300)
      rescue
        output_service_log(@process)
        raise
      end
    end

    def stop
      wait_for_tasks_to_finish
      stop_workers
      @process.stop
    end

    def hard_stop
      stop_workers
      @process.stop
    end

    def print_current_tasks
      @database.current_tasks.each do |current_task|
        @logger.error("#{DEBUG_HEADER} Current task '#{current_task[:description]}' #{DEBUG_HEADER}:")
        @logger.error(File.read(File.join(current_task[:output], 'debug')))
        @logger.error("#{DEBUG_HEADER} End of task '#{current_task[:description]}' #{DEBUG_HEADER}:")
      end
    end

    def wait_for_tasks_to_finish
      @logger.debug('Waiting for Delayed Job queue to drain...')
      attempt = 0
      delay = 0.1
      timeout = 60
      max_attempts = timeout/delay

      until delayed_job_done?
        if attempt > max_attempts
          @logger.error("Delayed Job queue failed to drain in #{timeout} seconds}")
          @database.current_tasks.each do |current_task|
            @logger.error("#{DEBUG_HEADER} Current task '#{current_task[:description]}' #{DEBUG_HEADER}:")
            @logger.error(File.read(File.join(current_task[:output], 'debug')))
            @logger.error("#{DEBUG_HEADER} End of task '#{current_task[:description]}' #{DEBUG_HEADER}:")
          end

          raise "Delayed Job queue failed to drain in #{timeout} seconds"
        end

        attempt += 1
        sleep delay
      end
      @logger.debug('Delayed Job queue drained')
    end

    def db_config
      YAML.load_file(@director_config)['db']
    end

    private

    def migrate_database(force_migration)
      if !@database_migrated || force_migration
        @database_migrator.migrate
        @database_migrated = true
      end
    end

    def delayed_job_ready?
      started = true
      @worker_processes.each do |worker|
        started = started && worker.stdout_contents.include?('Starting job worker')
      end
      started
    end

    def start_workers
      @worker_processes.each(&:start)
      attempt = 0
      delay = 0.5
      timeout = 60 * 5
      max_attempts = timeout/delay

      until delayed_job_ready?
        if attempt > max_attempts
          @logger.error("Delayed Job queue failed to start in #{timeout} seconds.")
          raise "Delayed Job failed to start workers in #{timeout} seconds"
        end

        attempt += 1
        sleep delay
      end

      start_monitor_workers
    end

    def stop_workers
      # wait for workers in parallel for fastness
      stop_monitor_workers
      @worker_processes.map { |worker_process| Thread.new {
        child_processes = worker_process.get_child_pids
        worker_process.stop
        child_processes.each do |pid|
          # if we kill worker children before the parent, the parent sees the
          # failed child process and marks the task as a failure which is not
          # what we are wanting to simulate with this sort of stop
          worker_process.kill_pid(pid, 'KILL')
        end
      } }.each(&:join)
    end

    def start_monitor_workers
      @monitor_workers = true
      monitor_workers
    end

    def stop_monitor_workers
      @monitor_workers = false
    end

    def monitor_workers
      Thread.new do
        while @monitor_workers
          @worker_processes.map(&:pid).each do |worker_pid|
            begin
              Process.kill(0, worker_pid)
            rescue Errno::ESRCH
              raise "Worker is no longer running (PID #{worker_pid})"
            end
          end
          sleep(5)
        end
      end
    end

    def reset
      FileUtils.rm_rf(@director_tmp_path)
      FileUtils.mkdir_p(@director_tmp_path)
    end

    def write_config(config)
      contents = config.render(DIRECTOR_CONF_TEMPLATE)
      File.open(@director_config, 'w+') do |f|
        f.write(contents)
      end
    end

    def delayed_job_done?
      @database.current_locked_jobs.count == 0
    end

    DEBUG_HEADER = '*' * 20

    def output_service_log(service)
      @logger.error("#{DEBUG_HEADER} start #{service.description} stdout #{DEBUG_HEADER}")
      @logger.error(service.stdout_contents)
      @logger.error("#{DEBUG_HEADER} end #{service.description} stdout #{DEBUG_HEADER}")

      @logger.error("#{DEBUG_HEADER} start #{service.description} stderr #{DEBUG_HEADER}")
      @logger.error(service.stderr_contents)
      @logger.error("#{DEBUG_HEADER} end #{service.description} stderr #{DEBUG_HEADER}")
    end
  end
end
