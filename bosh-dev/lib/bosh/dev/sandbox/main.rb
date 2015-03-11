require 'benchmark'
require 'securerandom'
require 'bosh/director/config'
require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'
require 'bosh/dev/sandbox/database_migrator'
require 'bosh/dev/sandbox/postgresql'
require 'bosh/dev/sandbox/mysql'
require 'bosh/dev/sandbox/nginx'
require 'bosh/dev/sandbox/workspace'
require 'bosh/dev/sandbox/director_config'
require 'bosh/dev/sandbox/port_provider'
require 'cloud/dummy'
require 'logging'

module Bosh::Dev::Sandbox
  class Main
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    UAA_ASSETS_DIR = File.expand_path('spec/assets/uaa', REPO_ROOT)

    DIRECTOR_UUID = 'deadbeef'

    DIRECTOR_CONFIG = 'director_test.yml'
    DIRECTOR_CONF_TEMPLATE = File.join(ASSETS_DIR, 'director_test.yml.erb')

    DIRECTOR_NGINX_CONFIG = 'director_nginx.conf'
    DIRECTOR_NGINX_CONF_TEMPLATE = File.join(ASSETS_DIR, 'director_nginx.conf.erb')

    DIRECTOR_NGINX_SSL_CERT = File.join(ASSETS_DIR, 'ca', 'ca.pem')
    DIRECTOR_NGINX_SSL_CERT_KEY = File.join(ASSETS_DIR, 'ca', 'ca.key')

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

    attr_accessor :director_fix_stateful_nodes
    attr_reader :logs_path

    attr_reader :cpi

    attr_accessor :external_cpi_enabled

    attr_reader :nats_log_path

    def self.from_env
      db_opts = {
        type: ENV['DB'] || 'postgresql',
        user: ENV['TRAVIS'] ? 'travis' : 'root',
        password: ENV['TRAVIS'] ? '' : 'password',
      }

      new(
        db_opts,
        ENV['DEBUG'],
        ENV['TEST_ENV_NUMBER'].to_i,
        Logging.logger(STDOUT),
      )
    end

    def initialize(db_opts, debug, test_env_number, logger)
      @debug = debug
      @logger = logger
      @name = SecureRandom.uuid.gsub('-', '')

      @port_provider = PortProvider.new(test_env_number)

      @logs_path = sandbox_path('logs')
      @dns_db_path = sandbox_path('director-dns.sqlite')
      @task_logs_dir = sandbox_path('boshdir/tasks')
      @director_tmp_path = sandbox_path('boshdir')
      @blobstore_storage_dir = sandbox_path('bosh_test_blobstore')

      FileUtils.mkdir_p(@logs_path)

      setup_redis
      setup_nats
      setup_nginx
      setup_director
      setup_heath_monitor
      setup_database(db_opts)

      setup_uaa

      # Note that this is not the same object
      # as dummy cpi used inside bosh-director process
      @cpi = Bosh::Clouds::Dummy.new(
        'dir' => cloud_storage_dir
      )
    end

    def agent_tmp_path
      cloud_storage_dir
    end

    def sandbox_path(path)
      File.join(sandbox_root, path)
    end

    def start
      @logger.info("Debug logs are saved to #{saved_logs_path}")
      setup_sandbox_root

      FileUtils.mkdir_p(cloud_storage_dir)
      FileUtils.rm_rf(logs_path)
      FileUtils.mkdir_p(logs_path)

      @redis_process.start
      @redis_socket_connector.try_to_connect

      @director_nginx_process.start
      @director_nginx_socket_connector.try_to_connect

      @nats_process.start
      @nats_socket_connector.try_to_connect

      @database.create_db
      @database_created = true
      @database_migrator.migrate


      start_uaa if @user_authentication == 'uaa'

      start_director
      start_workers
    end

    def director_config
      attributes = {
        sandbox_root: sandbox_root,
        database: @database,
        blobstore_storage_dir: blobstore_storage_dir,
        director_fix_stateful_nodes: director_fix_stateful_nodes,
        external_cpi_enabled: external_cpi_enabled,
        external_cpi_config: external_cpi_config,
        cloud_storage_dir: cloud_storage_dir,
        user_authentication: @user_authentication,
      }
      DirectorConfig.new(attributes, @port_provider)
    end

    def reset(name)
      time = Benchmark.realtime { do_reset(name) }
      @logger.info("Reset took #{time} seconds")
    end

    def restart_director
      stop_workers
      stop_director

      yield if block_given?

      start_director
      start_workers
    end

    def reconfigure_health_monitor(erb_template)
      @health_monitor_process.stop
      write_in_sandbox(HM_CONFIG, load_config_template(File.join(ASSETS_DIR, erb_template)))
      @health_monitor_process.start
    end

    def cloud_storage_dir
      sandbox_path('bosh_cloud_test')
    end

    def saved_logs_path
      File.join(Workspace.dir, "#{@name}.log")
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

      stop_workers
      stop_director

      @director_nginx_process.stop
      @redis_process.stop
      @nats_process.stop

      @health_monitor_process.stop
      @uaa_process.stop

      @database.drop_db
      FileUtils.rm_f(dns_db_path)
      FileUtils.rm_rf(agent_tmp_path)
      FileUtils.rm_rf(blobstore_storage_dir)
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
      @nats_port ||= @port_provider.get_port(:nats)
    end

    def hm_port
      @hm_port ||= @port_provider.get_port(:hm)
    end

    def director_url
      @director_url ||= "https://127.0.0.1:#{director_port}"
    end

    def director_port
      @director_port ||= @port_provider.get_port(:director)
    end

    def uaa_port
      @uaa_port ||= @port_provider.get_port(:uaa)
    end

    def director_ruby_port
      @director_ruby_port ||= @port_provider.get_port(:director_ruby)
    end

    def redis_port
      @redis_port ||= @port_provider.get_port(:redis)
    end

    def sandbox_root
      File.join(Workspace.dir, 'sandbox')
    end

    def reconfigure_sandbox(options)
      @user_authentication = options.fetch(:user_authentication, 'local')
    end

    def external_cpi_config
      {
        name: 'test-cpi',
        exec_path: File.join(REPO_ROOT, 'bosh-director', 'bin', 'dummy_cpi'),
        job_path: sandbox_path(EXTERNAL_CPI),
        config_path: sandbox_path(DIRECTOR_CONFIG),
        env_path: ENV['PATH']
      }
    end

    def director_ssl_cert_path
      DIRECTOR_NGINX_SSL_CERT
    end

    def director_ssl_cert_key_path
      DIRECTOR_NGINX_SSL_CERT_KEY
    end

    private

    def start_director
      if director_configuration_changed?
        write_director_config
      end

      reset_director_tmp_path

      @director_process.start

      begin
        # CI does not have enough time to start bosh-director
        # for some parallel tests; increasing to 60 secs (= 300 tries).
        @director_socket_connector.try_to_connect(300)
      rescue
        output_service_log(@director_process)
        raise
      end
    end

    def start_uaa
      @uaa_process.start

      begin
        @uaa_socket_connector.try_to_connect(300)
      rescue
        output_service_log(@uaa_process)
        raise
      end
    end

    def start_workers
      @worker_processes.each(&:start)
      until resque_is_ready?
        @logger.debug('Waiting for Resque workers to start')
        sleep 0.5
      end
    end

    def reset_director_tmp_path
      FileUtils.rm_rf(director_tmp_path)
      FileUtils.mkdir_p(director_tmp_path)
      File.open(File.join(director_tmp_path, 'state.json'), 'w') do |f|
        f.write(Yajl::Encoder.encode('uuid' => DIRECTOR_UUID))
      end
    end

    def stop_workers
      @logger.debug('Waiting for Resque queue to drain...')
      sleep 0.1 until resque_is_done?
      @logger.debug('Resque queue drained')

      Redis.new(host: 'localhost', port: redis_port).flushdb

      # wait for resque workers in parallel for fastness
      @worker_processes.map { |worker_process| Thread.new { worker_process.stop } }.each(&:join)
    end

    def stop_director
      @director_process.stop
    end

    def do_reset(name)
      @cpi.kill_agents

      restart_director do
        @database.truncate_db

        FileUtils.rm_rf(blobstore_storage_dir)
        FileUtils.mkdir_p(blobstore_storage_dir)
      end
    end

    def resque_is_done?
      info = Resque.info
      info[:pending] == 0 && info[:working] == 0
    end

    def resque_is_ready?
      info = Resque.info
      info[:workers] == @worker_processes.size
    end

    def setup_sandbox_root
      write_director_config
      write_in_sandbox(DIRECTOR_NGINX_CONFIG, load_config_template(DIRECTOR_NGINX_CONF_TEMPLATE))
      write_in_sandbox(HM_CONFIG, load_config_template(HM_CONF_TEMPLATE))
      write_in_sandbox(REDIS_CONFIG, load_config_template(REDIS_CONF_TEMPLATE))
      write_in_sandbox(EXTERNAL_CPI, load_config_template(EXTERNAL_CPI_TEMPLATE))
      FileUtils.chmod(0755, sandbox_path(EXTERNAL_CPI))
      FileUtils.mkdir_p(sandbox_path('redis'))
      FileUtils.mkdir_p(blobstore_storage_dir)
    end

    def write_director_config
      write_in_sandbox(DIRECTOR_CONFIG, director_config.render(DIRECTOR_CONF_TEMPLATE))
    end

    def director_configuration_changed?
      read_from_sandbox(DIRECTOR_CONFIG) != director_config.render(DIRECTOR_CONF_TEMPLATE)
    end

    def read_from_sandbox(filename)
      Dir.chdir(sandbox_root) do
        File.read(filename)
      end
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

    DEBUG_HEADER = '*' * 20

    def output_service_log(service)
      @logger.error("#{DEBUG_HEADER} start #{service.description} stdout #{DEBUG_HEADER}")
      @logger.error(service.stdout_contents)
      @logger.error("#{DEBUG_HEADER} end #{service.description} stdout #{DEBUG_HEADER}")

      @logger.error("#{DEBUG_HEADER} start #{service.description} stderr #{DEBUG_HEADER}")
      @logger.error(service.stderr_contents)
      @logger.error("#{DEBUG_HEADER} end #{service.description} stderr #{DEBUG_HEADER}")
    end


    def setup_database(db_opts)
      if db_opts[:type] == 'mysql'
        @database = Mysql.new(@name, @logger, db_opts[:user], db_opts[:password])
      else
        @database = Postgresql.new(@name, @logger)
      end

      director_config = sandbox_path(DIRECTOR_CONFIG)
      @database_migrator = DatabaseMigrator.new(DIRECTOR_PATH, director_config, @logger)
    end

    def setup_heath_monitor
      @health_monitor_process = Service.new(
        %W[bosh-monitor -c #{sandbox_path(HM_CONFIG)}],
        {output: "#{logs_path}/health_monitor.out"},
        @logger,
      )
    end

    def setup_uaa
      base_log_path = File.join(logs_path, @name)
      @uaa_process = Service.new(
        %W[./gradlew run],
        {output: "#{base_log_path}.uaa.out",
         env: {'CARGO_PORT' => "#{uaa_port}"},
         working_dir: UAA_ASSETS_DIR
        },
        @logger,
      )
      @uaa_socket_connector = SocketConnector.new('uaa', 'localhost', uaa_port, @logger)
    end

    def setup_director
      base_log_path = File.join(logs_path, @name)

      director_config = sandbox_path(DIRECTOR_CONFIG)
      @director_process = Service.new(
        %W[bosh-director -c #{director_config}],
        {output: "#{base_log_path}.director.out"},
        @logger,
      )

      @director_nginx_socket_connector = SocketConnector.new('director_nginx', 'localhost', director_port, @logger)

      @director_socket_connector = SocketConnector.new('director', 'localhost', director_ruby_port, @logger)

      @worker_processes = 3.times.map do |index|
        Service.new(
          %W[bosh-director-worker -c #{director_config}],
          {output: "#{base_log_path}.worker_#{index}.out", env: {'QUEUE' => '*'}},
          @logger,
        )
      end

      @scheduler_process = Service.new(
        %W[bosh-director-scheduler -c #{director_config}],
        {output: "#{base_log_path}.scheduler.out"},
        @logger,
      )
    end

    def setup_nginx
      @nginx = Nginx.new

      @director_nginx_process = Service.new(
        %W[#{@nginx.executable_path} -c #{sandbox_path(DIRECTOR_NGINX_CONFIG)}], {}, @logger)
    end

    def setup_nats
      @nats_log_path = File.join(@logs_path, 'nats.log')

      @nats_process = Service.new(
        %W[nats-server -p #{nats_port} -D -V -T -l #{@nats_log_path}],
        {stdout: $stdout, stderr: $stderr},
        @logger
      )

      @nats_socket_connector = SocketConnector.new('nats', 'localhost', nats_port, @logger)
    end

    def setup_redis
      @redis_process = Service.new(%W[redis-server #{sandbox_path(REDIS_CONFIG)}], {}, @logger)
      @redis_socket_connector = SocketConnector.new('redis', 'localhost', redis_port, @logger)
      Bosh::Director::Config.redis_options = {host: 'localhost', port: redis_port}
    end

    attr_reader :director_tmp_path, :dns_db_path, :task_logs_dir
  end
end
