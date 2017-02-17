require 'benchmark'
require 'securerandom'
require 'bosh/director/config'
require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/http_endpoint_connector'
require 'bosh/dev/sandbox/socket_connector'
require 'bosh/dev/sandbox/postgresql'
require 'bosh/dev/sandbox/mysql'
require 'bosh/dev/sandbox/nginx'
require 'bosh/dev/sandbox/workspace'
require 'bosh/dev/sandbox/director_config'
require 'bosh/dev/sandbox/port_provider'
require 'bosh/dev/sandbox/services/director_service'
require 'bosh/dev/sandbox/services/nginx_service'
require 'bosh/dev/sandbox/services/connection_proxy_service'
require 'bosh/dev/sandbox/services/uaa_service'
require 'bosh/dev/sandbox/services/config_server_service'
require 'cloud/dummy'
require 'logging'

module Bosh::Dev::Sandbox
  class Main
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    SANDBOX_ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    HM_CONFIG = 'health_monitor.yml'
    DEFAULT_HM_CONF_TEMPLATE_NAME = 'health_monitor.yml.erb'

    EXTERNAL_CPI = 'cpi'
    EXTERNAL_CPI_TEMPLATE = File.join(SANDBOX_ASSETS_DIR, 'cpi.erb')

    UPGRADE_SPEC_ASSETS_DIR =  File.expand_path('spec/assets/upgrade', REPO_ROOT)

    attr_reader :name
    attr_reader :health_monitor_process
    attr_reader :scheduler_process

    attr_reader :director_service
    attr_reader :port_provider

    attr_reader :database_proxy

    alias_method :db_name, :name
    attr_reader :blobstore_storage_dir
    attr_reader :verify_multidigest_path

    attr_reader :logger, :logs_path

    attr_reader :cpi

    attr_reader :nats_log_path

    attr_accessor :trusted_certs

    def self.from_env
      db_opts = {
        type: ENV['DB'] || 'postgresql',
        user: ENV['TRAVIS'] ? 'travis' : 'root',
        password: ENV['TRAVIS'] ? '' : 'password',
      }

      logger = Logging.logger(STDOUT)
      logger.level = ENV.fetch('LOG_LEVEL', 'DEBUG')

      new(
        db_opts,
        ENV['DEBUG'],
        ENV['TEST_ENV_NUMBER'].to_i,
        logger,
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
      @blobstore_storage_dir = sandbox_path('bosh_test_blobstore')
      @verify_multidigest_path = File.join(REPO_ROOT, 'tmp', 'verify-multidigest', 'verify-multidigest')

      FileUtils.mkdir_p(@logs_path)

      setup_nats

      @uaa_service = UaaService.new(@port_provider, sandbox_root, base_log_path, @logger)
      @config_server_service = ConfigServerService.new(@port_provider, base_log_path, @logger, test_env_number)
      @nginx_service = NginxService.new(sandbox_root, director_port, director_ruby_port, @uaa_service.port, @logger)

      setup_database(db_opts)

      director_config = sandbox_path(DirectorService::DEFAULT_DIRECTOR_CONFIG)
      director_tmp_path = sandbox_path('boshdir')
      @director_service = DirectorService.new(
        {
          database: @database,
          database_proxy: @database_proxy,
          director_port: director_ruby_port,
          base_log_path: base_log_path,
          director_tmp_path: director_tmp_path,
          director_config: director_config
        },
        @logger
      )
      setup_heath_monitor

      @scheduler_process = Service.new(
        %W[bosh-director-scheduler -c #{director_config}],
        {output: "#{base_log_path}.scheduler.out"},
        @logger,
      )

      # Note that this is not the same object
      # as dummy cpi used inside bosh-director process
      @cpi = Bosh::Clouds::Dummy.new(
        'dir' => cloud_storage_dir,
        'agent' => {'blobstore' => {}},
        'nats' => "nats://localhost:#{nats_port}"
      )
      reconfigure({})
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

      @database_proxy && @database_proxy.start

      @nginx_service.start

      @nats_process.start
      @nats_socket_connector.try_to_connect

      @database.create_db

      unless @test_initial_state.nil?
        load_db_and_populate_blobstore(@test_initial_state)
      end

      @uaa_service.start if @user_authentication == 'uaa'
      @config_server_service.start(@with_config_server_trusted_certs) if @config_server_enabled

      dir_config = director_config
      @director_name = dir_config.director_name

      @director_service.start(dir_config)
    end

    def director_name
      @director_name || raise("Test inconsistency: Director name is not set")
    end

    def director_config
      attributes = {
        sandbox_root: sandbox_root,
        database: @database,
        blobstore_storage_dir: blobstore_storage_dir,
        verify_multidigest_path: verify_multidigest_path,
        director_fix_stateful_nodes: @director_fix_stateful_nodes,
        dns_enabled: @dns_enabled,
        local_dns: @local_dns,
        external_cpi_config: external_cpi_config,
        cloud_storage_dir: cloud_storage_dir,
        config_server_enabled: @config_server_enabled,
        user_authentication: @user_authentication,
        trusted_certs: @trusted_certs,
        users_in_manifest: @users_in_manifest,
        enable_post_deploy: @enable_post_deploy,
        enable_nats_delivered_templates: @enable_nats_delivered_templates,
        generate_vm_passwords: @generate_vm_passwords,
        remove_dev_tools: @remove_dev_tools,
        director_ips: @director_ips
      }
      DirectorConfig.new(attributes, @port_provider)
    end

    def reset
      time = Benchmark.realtime { do_reset }
      @logger.info("Reset took #{time} seconds")
    end

    def reconfigure_health_monitor(erb_template=DEFAULT_HM_CONF_TEMPLATE_NAME)
      @health_monitor_process.stop
      write_in_sandbox(HM_CONFIG, load_config_template(File.join(SANDBOX_ASSETS_DIR, erb_template)))
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

      @director_service.stop

      @nginx_service.stop
      @nats_process.stop

      @health_monitor_process.stop
      @uaa_service.stop

      @config_server_service.stop

      @database.drop_db
      @database_proxy && @database_proxy.stop

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

    def db
      Sequel.connect(@director_service.db_config)
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
      @director_port ||= @port_provider.get_port(:nginx)
    end

    def director_ruby_port
      @director_ruby_port ||= @port_provider.get_port(:director_ruby)
    end

    def sandbox_root
      File.join(Workspace.dir, 'sandbox')
    end

    def reconfigure(options)
      @user_authentication = options.fetch(:user_authentication, 'local')
      @config_server_enabled = options.fetch(:config_server_enabled, false)
      @drop_database = options.fetch(:drop_database, false)
      @test_initial_state = options.fetch(:test_initial_state, nil)
      @with_config_server_trusted_certs = options.fetch(:with_config_server_trusted_certs, true)
      @director_fix_stateful_nodes = options.fetch(:director_fix_stateful_nodes, false)
      @dns_enabled = options.fetch(:dns_enabled, true)
      @local_dns = options.fetch(:local_dns, {enabled: false, include_index: false})
      @nginx_service.reconfigure(options[:ssl_mode])
      @uaa_service.reconfigure(options[:uaa_encryption])
      @users_in_manifest = options.fetch(:users_in_manifest, true)
      @enable_post_deploy = options.fetch(:enable_post_deploy, false)
      @enable_nats_delivered_templates = options.fetch(:enable_nats_delivered_templates, false)
      @generate_vm_passwords = options.fetch(:generate_vm_passwords, false)
      @remove_dev_tools = options.fetch(:remove_dev_tools, false)
      @director_ips = options.fetch(:director_ips, [])
    end

    def certificate_path
      File.join(SANDBOX_ASSETS_DIR, 'ca', 'certs', 'rootCA.pem')
    end

    private

    def load_db_and_populate_blobstore(test_initial_state)
      @database.load_db_initial_state(File.join(UPGRADE_SPEC_ASSETS_DIR, test_initial_state))

      if @database.adapter.eql? 'mysql2'
        tar_filename = 'blobstore_snapshot_with_mysql.tar.gz'
      elsif @database.adapter.eql? 'postgres'
        tar_filename = 'blobstore_snapshot_with_postgres.tar.gz'
      else
        raise 'Pre-loading blobstore supported only for PostgresDB and MySQL'
      end

      blobstore_snapshot_path = File.join(UPGRADE_SPEC_ASSETS_DIR, test_initial_state, tar_filename)
      @logger.info("Pre-filling blobstore `#{blobstore_storage_dir}` with blobs from `#{blobstore_snapshot_path}`")
      tar_out = `tar xzvf #{blobstore_snapshot_path} -C #{blobstore_storage_dir}  2>&1`
      if $?.exitstatus != 0
        raise "Cannot pre-fill blobstore: #{tar_out}"
      end
    end

    def external_cpi_config
      {
        name: 'test-cpi',
        exec_path: File.join(REPO_ROOT, 'bosh-director', 'bin', 'dummy_cpi'),
        job_path: sandbox_path(EXTERNAL_CPI),
        config_path: sandbox_path(DirectorService::DEFAULT_DIRECTOR_CONFIG),
        env_path: ENV['PATH'],
        gem_home: ENV['GEM_HOME'],
        gem_path: ENV['GEM_PATH']
      }
    end

    def do_reset
      @cpi.kill_agents

      @director_service.stop

      if @drop_database
        @database.drop_db
        @database.create_db
      else
        @database.truncate_db
      end

      FileUtils.rm_rf(blobstore_storage_dir)
      FileUtils.mkdir_p(blobstore_storage_dir)

      unless @test_initial_state.nil?
        load_db_and_populate_blobstore(@test_initial_state)
      end

      @uaa_service.start if @user_authentication == 'uaa'
      @config_server_service.restart(@with_config_server_trusted_certs) if @config_server_enabled

      @director_service.start(director_config, @drop_database)

      @nginx_service.restart_if_needed

      @cpi.reset
    end

    def setup_sandbox_root
      hm_template_path = File.join(SANDBOX_ASSETS_DIR, DEFAULT_HM_CONF_TEMPLATE_NAME)
      write_in_sandbox(HM_CONFIG, load_config_template(hm_template_path))
      write_in_sandbox(EXTERNAL_CPI, load_config_template(EXTERNAL_CPI_TEMPLATE))
      FileUtils.chmod(0755, sandbox_path(EXTERNAL_CPI))
      FileUtils.mkdir_p(blobstore_storage_dir)
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

    def setup_database(db_opts)
      if db_opts[:type] == 'mysql'
        @database = Mysql.new(@name, @logger, Bosh::Core::Shell.new, db_opts[:user], db_opts[:password])
      else
        @database = Postgresql.new(@name, @logger, @port_provider.get_port(:postgres))
        # all postgres connections go through this proxy (for testing automatic reconnect)
        @database_proxy = ConnectionProxyService.new(sandbox_root, '127.0.0.1', 5432, @port_provider.get_port(:postgres), base_log_path, @logger)
      end
    end

    def setup_heath_monitor
      @health_monitor_process = Service.new(
        %W[bosh-monitor -c #{sandbox_path(HM_CONFIG)}],
        {output: "#{logs_path}/health_monitor.out"},
        @logger,
      )
    end

    def base_log_path
      File.join(logs_path, @name)
    end

    def setup_nats
      @nats_log_path = File.join(@logs_path, 'nats.log')

      @nats_process = Service.new(
        %W[nats-server -p #{nats_port} -T -l #{@nats_log_path}],
        {stdout: $stdout, stderr: $stderr},
        @logger
      )

      @nats_socket_connector = SocketConnector.new('nats', 'localhost', nats_port, @nats_log_path, @logger)
    end

    attr_reader :director_tmp_path, :dns_db_path, :task_logs_dir
  end
end
