require 'logger'
require 'benchmark'
require 'securerandom'
require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'
require 'bosh/dev/sandbox/database_migrator'
require 'bosh/dev/sandbox/postgresql'
require 'bosh/dev/sandbox/mysql'
require 'cloud/dummy'

module Bosh::Dev::Sandbox
  class Main
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    DIRECTOR_UUID = 'deadbeef'

    DIRECTOR_CONFIG = 'director_test.yml'
    DIRECTOR_CONF_TEMPLATE = File.join(ASSETS_DIR, 'director_test.yml.erb')

    REDIS_CONFIG = 'redis_test.conf'
    REDIS_CONF_TEMPLATE = File.join(ASSETS_DIR, 'redis_test.conf.erb')

    HM_CONFIG = 'health_monitor.yml'
    HM_CONF_TEMPLATE = File.join(ASSETS_DIR, 'health_monitor.yml.erb')

    EXTERNAL_CPI = 'cpi'
    EXTERNAL_CPI_TEMPLATE = File.join(ASSETS_DIR, 'cpi.erb')

    DIRECTOR_PATH = File.expand_path('bosh-director', REPO_ROOT)
    MIGRATIONS_PATH = File.join(DIRECTOR_PATH, 'db', 'migrations')

    attr_reader :name
    attr_reader :health_monitor_process
    attr_reader :scheduler_process

    alias_method :db_name, :name
    attr_reader :blobstore_storage_dir
    attr_reader :agent_type

    attr_accessor :director_fix_stateful_nodes
    attr_reader :logs_path

    attr_reader :cpi

    attr_accessor :external_cpi_enabled

    def self.from_env
      db_opts = {
        type: ENV['DB'] || 'postgresql',
        user: ENV['TRAVIS'] ? 'travis' : 'root',
        password: ENV['TRAVIS'] ? '' : 'password',
      }

      agent_type = ENV['BOSH_INTEGRATION_AGENT_TYPE'] || 'ruby'

      new(
        db_opts,
        ENV['DEBUG'],
        agent_type,
        ENV['TEST_ENV_NUMBER'].to_i,
        Logger.new(STDOUT),
      )
    end

    def initialize(db_opts, debug, agent_type, test_env_number, logger)
      @debug = debug
      @agent_type = agent_type
      @test_env_number = test_env_number
      @logger = logger
      @name = SecureRandom.hex(6)

      @logs_path = sandbox_path('logs')
      @dns_db_path = sandbox_path('director-dns.sqlite')
      @task_logs_dir = sandbox_path('boshdir/tasks')
      @director_tmp_path = sandbox_path('boshdir')
      @blobstore_storage_dir = sandbox_path('bosh_test_blobstore')

      director_config = sandbox_path(DIRECTOR_CONFIG)
      base_log_path = File.join(logs_path, @name)

      @redis_process = Service.new(
        %W[redis-server #{sandbox_path(REDIS_CONFIG)}], {}, @logger)

      @redis_socket_connector = SocketConnector.new(
        'redis', 'localhost', redis_port, @logger)

      @nats_process = Service.new(%W[nats-server -p #{nats_port}], {}, @logger)

      @nats_socket_connector = SocketConnector.new(
        'nats', 'localhost', nats_port, @logger)

      @director_process = Service.new(
        %W[bosh-director -c #{director_config}],
        { output: "#{base_log_path}.director.out" },
        @logger,
      )

      @director_socket_connector = SocketConnector.new(
        'director', 'localhost', director_port, @logger)

      @worker_processes = 3.times.map do |index|
        Service.new(
          %W[bosh-director-worker -c #{director_config}],
          { output: "#{base_log_path}.worker_#{index}.out", env: { 'QUEUE' => '*' } },
          @logger,
        )
      end

      @health_monitor_process = Service.new(
        %W[bosh-monitor -c #{sandbox_path(HM_CONFIG)}],
        { output: "#{logs_path}/health_monitor.out" },
        @logger,
      )

      @scheduler_process = Service.new(
        %W[bosh-director-scheduler -c #{director_config}],
        { output: "#{base_log_path}.scheduler.out" },
        @logger,
      )

      if db_opts[:name] == 'mysql'
        @database = Mysql.new(@name, @logger, db_opts[:user], db_opts[:password])
      else
        @database = Postgresql.new(@name, @logger)
      end

      # Note that this is not the same object
      # as dummy cpi used inside bosh-director process
      @cpi = Bosh::Clouds::Dummy.new(
        'dir' => cloud_storage_dir,
        'agent' => { 'type' => agent_type },
      )

      @database_migrator = DatabaseMigrator.new(DIRECTOR_PATH, director_config, @logger)
    end

    def agent_tmp_path
      cloud_storage_dir
    end

    def sandbox_path(path)
      File.join(sandbox_root, path)
    end

    def start
      setup_sandbox_root

      @redis_process.start
      @redis_socket_connector.try_to_connect

      @nats_process.start
      @nats_socket_connector.try_to_connect

      FileUtils.mkdir_p(cloud_storage_dir)
      FileUtils.rm_rf(logs_path)
      FileUtils.mkdir_p(logs_path)
    end

    def reset(name)
      time = Benchmark.realtime { do_reset(name) }
      @logger.info("Reset took #{time} seconds")
    end

    def reconfigure_director
      @director_process.stop
      write_in_sandbox(DIRECTOR_CONFIG, load_config_template(DIRECTOR_CONF_TEMPLATE))
      @director_process.start
    end

    def reconfigure_workers
      @worker_processes.each(&:stop)
      write_in_sandbox(DIRECTOR_CONFIG, load_config_template(DIRECTOR_CONF_TEMPLATE))
      @worker_processes.each(&:start)
    end

    def reconfigure_health_monitor(erb_template)
      @health_monitor_process.stop
      write_in_sandbox(HM_CONFIG, load_config_template(File.join(ASSETS_DIR, erb_template)))
      @health_monitor_process.start
    end

    def cloud_storage_dir
      sandbox_path('bosh_cloud_test')
    end

    def save_task_logs(name)
      if @debug && File.directory?(task_logs_dir)
        task_name = "task_#{name}_#{SecureRandom.hex(6)}"
        FileUtils.mv(task_logs_dir, File.join(logs_path, task_name))
      end
    end

    def stop
      @cpi.kill_agents
      @scheduler_process.stop
      @worker_processes.each(&:stop)
      @director_process.stop
      @redis_process.stop
      @nats_process.stop
      @health_monitor_process.stop
      @database.drop_db
      FileUtils.rm_f(dns_db_path)
      FileUtils.rm_rf(director_tmp_path)
      FileUtils.rm_rf(agent_tmp_path)
      FileUtils.rm_rf(blobstore_storage_dir)

      # Hardcoded in bosh/spec/assets/test_release_template/config/final.yml
      FileUtils.rm_rf('/tmp/bosh-integration-tests')
    end

    def run
      start
      @logger.info('Sandbox running, type ctrl+c to stop')

      loop { sleep 60 }

    # rubocop:disable HandleExceptions
    rescue Interrupt
    # rubocop:enable HandleExceptions
    ensure
      stop
      @logger.info('Stopped sandbox')
    end

    def nats_port
      @nats_port ||= get_named_port(:nats)
    end

    def hm_port
      @hm_port ||= get_named_port(:hm)
    end

    def director_port
      @director_port ||= get_named_port(:director)
    end

    def redis_port
      @redis_port ||= get_named_port(:redis)
    end

    def sandbox_root
      @sandbox_root ||= Dir.mktmpdir.tap { |p| @logger.info("sandbox=#{p}") }
    end

    def external_cpi_config
      {
        exec_path: File.join(REPO_ROOT, 'bosh-director', 'bin', 'dummy_cpi'),
        director_path: sandbox_path(EXTERNAL_CPI),
        config_path: sandbox_path(DIRECTOR_CONFIG),
        env_path: ENV['PATH']
      }
    end

    private

    def do_reset(name)
      @cpi.kill_agents
      @worker_processes.each(&:stop)
      @director_process.stop
      @health_monitor_process.stop

      Redis.new(host: 'localhost', port: redis_port).flushdb

      @database.drop_db if @database_created
      @database_created = true

      @database.create_db
      @database_migrator.migrate

      FileUtils.rm_rf(blobstore_storage_dir)
      FileUtils.mkdir_p(blobstore_storage_dir)
      FileUtils.rm_rf(director_tmp_path)
      FileUtils.mkdir_p(director_tmp_path)

      File.open(File.join(director_tmp_path, 'state.json'), 'w') do |f|
        f.write(Yajl::Encoder.encode('uuid' => DIRECTOR_UUID))
      end

      write_in_sandbox(DIRECTOR_CONFIG, load_config_template(DIRECTOR_CONF_TEMPLATE))
      write_in_sandbox(HM_CONFIG, load_config_template(HM_CONF_TEMPLATE))

      @director_process.start
      @worker_processes.each(&:start)

      begin
        # CI does not have enough time to start bosh-director
        # for some parallel tests; increasing to 60 secs (= 300 tries).
        @director_socket_connector.try_to_connect(300)
      rescue
        output_service_log(@director_process)
        raise
      end
    end

    def setup_sandbox_root
      write_in_sandbox(DIRECTOR_CONFIG, load_config_template(DIRECTOR_CONF_TEMPLATE))
      write_in_sandbox(HM_CONFIG, load_config_template(HM_CONF_TEMPLATE))
      write_in_sandbox(REDIS_CONFIG, load_config_template(REDIS_CONF_TEMPLATE))
      write_in_sandbox(EXTERNAL_CPI, load_config_template(EXTERNAL_CPI_TEMPLATE))
      FileUtils.chmod(0755, sandbox_path(EXTERNAL_CPI))
      FileUtils.mkdir_p(sandbox_path('redis'))
      FileUtils.mkdir_p(blobstore_storage_dir)
    end

    def write_in_sandbox(filename, contents)
      Dir.chdir(sandbox_root) do
        File.open(filename, 'w+') do |f|
          f.write(contents)
        end
      end
    end

    def load_config_template(filename)
      template_contents = File.read(filename)
      template = ERB.new(template_contents)
      template.result(binding)
    end

    def get_named_port(name)
      @port_names ||= []
      @port_names << name unless @port_names.include?(name)
      61000 + @test_env_number * 100 + @port_names.index(name)
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

    attr_reader :director_tmp_path, :dns_db_path, :task_logs_dir
  end
end
