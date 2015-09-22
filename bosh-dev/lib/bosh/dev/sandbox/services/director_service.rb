require 'bosh/dev/sandbox/database_migrator'

module Bosh::Dev::Sandbox
  class DirectorService

    REPO_ROOT = File.expand_path('../../../../../../', File.dirname(__FILE__))
    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)
    DIRECTOR_UUID = 'deadbeef'

    DEFAULT_DIRECTOR_CONFIG = 'director_test.yml'
    DIRECTOR_CONF_TEMPLATE = File.join(ASSETS_DIR, 'director_test.yml.erb')

    DIRECTOR_PATH = File.expand_path('bosh-director', REPO_ROOT)

    def initialize(options, logger)
      @database = options[:database]
      @redis_port = options[:redis_port]
      @logger = logger
      @director_tmp_path = options[:director_tmp_path]
      @director_config = options[:director_config]
      base_log_path = options[:base_log_path]

      log_location = "#{base_log_path}.director.out"
      @process = Service.new(
        %W[bosh-director -c #{@director_config}],
        {output: log_location},
        @logger,
      )

      @socket_connector = SocketConnector.new('director', 'localhost', options[:director_port], log_location, @logger)

      @worker_processes = 3.times.map do |index|
        Service.new(
          %W[bosh-director-worker -c #{@director_config}],
          {output: "#{base_log_path}.worker_#{index}.out", env: {'QUEUE' => '*'}},
          @logger,
        )
      end

      @database_migrator = DatabaseMigrator.new(DIRECTOR_PATH, @director_config, @logger)
    end

    def start(config)
      write_config(config)

      migrate_database

      reset

      @process.start

      start_workers

      begin
        # CI does not have enough time to start bosh-director
        # for some parallel tests; increasing to 60 secs (= 300 tries).
        @socket_connector.try_to_connect(300)
      rescue
        output_service_log(@process)
        raise
      end
    end

    def stop
      stop_workers
      @process.stop
    end

    private

    def migrate_database
      unless @database_migrated
        @database_migrator.migrate
      end

      @database_migrated = true
    end

    def start_workers
      @worker_processes.each(&:start)
      attempt = 0
      delay = 0.5
      timeout = 60 * 5
      max_attempts = timeout/delay

      until resque_is_ready?
        if attempt > max_attempts
          @logger.error("Resque queue failed to start in #{timeout} seconds. Resque.info: #{Resque.info.pretty_inspect}")
          raise "Resque failed to start workers in #{timeout} seconds"
        end

        attempt += 1
        sleep delay
      end
    end

    def stop_workers
      @logger.debug('Waiting for Resque queue to drain...')
      attempt = 0
      delay = 0.1
      timeout = 60
      max_attempts = timeout/delay

      until resque_is_done?
        if attempt > max_attempts
          @logger.error("Resque queue failed to drain in #{timeout} seconds. Resque.info: #{Resque.info.pretty_inspect}")
          @database.current_tasks.each do |current_task|
            @logger.error("#{DEBUG_HEADER} Current task '#{current_task[:description]}' #{DEBUG_HEADER}:")
            @logger.error(File.read(File.join(current_task[:output], 'debug')))
            @logger.error("#{DEBUG_HEADER} End of task '#{current_task[:description]}' #{DEBUG_HEADER}:")
          end

          raise "Resque queue failed to drain in #{timeout} seconds"
        end

        attempt += 1
        sleep delay
      end
      @logger.debug('Resque queue drained')

      Redis.new(host: 'localhost', port: @redis_port).flushdb

      # wait for resque workers in parallel for fastness
      @worker_processes.map { |worker_process| Thread.new { worker_process.stop } }.each(&:join)
    end

    def reset
      FileUtils.rm_rf(@director_tmp_path)
      FileUtils.mkdir_p(@director_tmp_path)
      File.open(File.join(@director_tmp_path, 'state.json'), 'w') do |f|
        f.write(Yajl::Encoder.encode('uuid' => DIRECTOR_UUID))
      end
    end

    def write_config(config)
      contents = config.render(DIRECTOR_CONF_TEMPLATE)
      File.open(@director_config, 'w+') do |f|
        f.write(contents)
      end
    end

    def resque_is_ready?
      info = Resque.info
      info[:workers] == @worker_processes.size
    end

    def resque_is_done?
      info = Resque.info
      info[:pending] == 0 && info[:working] == 0
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
