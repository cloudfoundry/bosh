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
require 'bosh/dev/sandbox/services/uaa_service'
require 'bosh/dev/sandbox/services/config_server_service'
require 'bosh/dev/gnatsd_manager'
require 'cloud/dummy'
require 'logging'

module Bosh::Dev::Sandbox
  class Main
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))

    SANDBOX_ASSETS_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    HM_CONFIG = 'health_monitor.yml'
    DEFAULT_HM_CONF_TEMPLATE_NAME = 'health_monitor.yml.erb'

    NATS_CONFIG = 'nats.conf'
    DEFAULT_NATS_CONF_TEMPLATE_NAME = 'nats.conf.erb'

    DIRECTOR_CERTIFICATE_EXPIRY_JSON_CONFIG = 'director_certificate_expiry.json'.freeze
    DIRECTOR_CERTIFICATE_EXPIRY_JSON_TEMPLATE_NAME = 'director_certificate_expiry.json.erb'.freeze

    EXTERNAL_CPI = 'cpi'
    EXTERNAL_CPI_TEMPLATE = File.join(SANDBOX_ASSETS_DIR, 'cpi.erb')

    EXTERNAL_CPI_CONFIG = 'cpi.json'
    EXTERNAL_CPI_CONFIG_TEMPLATE = File.join(SANDBOX_ASSETS_DIR, 'cpi_config.json.erb')

    UPGRADE_SPEC_ASSETS_DIR = File.expand_path('spec/assets/upgrade', REPO_ROOT)

    attr_reader :name
    attr_reader :health_monitor_process
    attr_reader :scheduler_process

    attr_reader :director_service
    attr_reader :port_provider

    alias_method :db_name, :name
    attr_reader :blobstore_storage_dir
    attr_reader :verify_multidigest_path

    attr_reader :logger, :logs_path

    attr_reader :cpi

    attr_reader :nats_log_path

    attr_reader :nats_url

    attr_reader :dummy_cpi_api_version

    attr_accessor :trusted_certs

    def self.from_env
      db_opts = {
        type: ENV['DB'] || 'postgresql',
        tls_enabled: ENV['DB_TLS'] == 'true',
      }
      db_opts[:password] = ENV['DB_PASSWORD'] if ENV['DB_PASSWORD']

      new(
        db_opts,
        ENV['DEBUG'],
        ENV['TEST_ENV_NUMBER'].to_i,
      )
    end

    def initialize(db_opts, debug, test_env_number)
      @debug = debug
      @name = SecureRandom.uuid.gsub('-', '')

      @port_provider = PortProvider.new(test_env_number)

      @logs_path = sandbox_path('logs')
      FileUtils.mkdir_p(@logs_path)

      @sandbox_log_file = File.open(sandbox_path('sandbox.log'), 'w+')

      @sandbox_log_file = STDOUT unless ENV.fetch('LOG_STDOUT', '').empty?
      @logger = Logging.logger(@sandbox_log_file)

      @logger.level = ENV.fetch('LOG_LEVEL', 'DEBUG')

      @dns_db_path = sandbox_path('director-dns.sqlite')
      @task_logs_dir = sandbox_path('boshdir/tasks')
      @blobstore_storage_dir = sandbox_path('bosh_test_blobstore')
      @verify_multidigest_path = File.join(REPO_ROOT, 'tmp', 'verify-multidigest', 'verify-multidigest')
      @dummy_cpi_api_version = nil

      @nats_log_path = File.join(@logs_path, 'nats.log')
      setup_nats

      @uaa_service = UaaService.new(@port_provider, sandbox_root, base_log_path, @logger)
      @config_server_service = ConfigServerService.new(@port_provider, base_log_path, @logger, test_env_number)
      @nginx_service = NginxService.new(sandbox_root, director_port, director_ruby_port, @uaa_service.port, base_log_path, @logger)

      @db_config = {
        ca_path: File.join(SANDBOX_ASSETS_DIR, 'database', 'rootCA.pem')
      }.merge(db_opts)

      setup_database(@db_config, nil)

      director_config_path = sandbox_path(DirectorService::DEFAULT_DIRECTOR_CONFIG)
      director_tmp_path = sandbox_path('boshdir')
      @director_service = DirectorService.new(
        {
          database: @database,
          director_port: director_ruby_port,
          base_log_path: base_log_path,
          director_tmp_path: director_tmp_path,
          director_config: director_config_path,
          audit_log_path: @logs_path,
        },
        @logger
      )
      setup_heath_monitor

      @scheduler_process = Service.new(
        %W[bosh-director-scheduler -c #{director_config_path}],
        {output: "#{base_log_path}.scheduler.out"},
        @logger,
      )

      # Note that this is not the same object
      # as dummy cpi used inside bosh-director process
      @cpi = Bosh::Clouds::Dummy.new(
        {
          'dir' => cloud_storage_dir,
          'agent' => {
            'blobstore' => {
              'provider' => 'local',
              'options' => {
                'blobstore_path' => @blobstore_storage_dir,
              },
            }
          },
          'nats' => @nats_url,
          'log_buffer' => @logger,
        },
        {},
        1
      )

      reconfigure
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
        agent_wait_timeout: @agent_wait_timeout,
        keep_unreachable_vms: @keep_unreachable_vms,
        blobstore_storage_dir: blobstore_storage_dir,
        cloud_storage_dir: cloud_storage_dir,
        config_server_enabled: @config_server_enabled,
        database: @database,
        default_update_vm_strategy: @default_update_vm_strategy,
        director_fix_stateful_nodes: @director_fix_stateful_nodes,
        director_ips: @director_ips,
        dns_enabled: @dns_enabled,
        enable_cpi_resize_disk: @enable_cpi_resize_disk,
        enable_nats_delivered_templates: @enable_nats_delivered_templates,
        enable_post_deploy: @enable_post_deploy,
        external_cpi_config: external_cpi_config,
        generate_vm_passwords: @generate_vm_passwords,
        local_dns: @local_dns,
        nats_client_ca_certificate_path: get_nats_client_ca_certificate_path,
        nats_client_ca_private_key_path: get_nats_client_ca_private_key_path,
        director_certificate_expiry_json_path: director_certificate_expiry_json_path,
        nats_director_tls: nats_certificate_paths['clients']['director'],
        nats_server_ca_path: get_nats_server_ca_path,
        networks: @networks,
        remove_dev_tools: @remove_dev_tools,
        sandbox_root: sandbox_root,
        trusted_certs: @trusted_certs,
        user_authentication: @user_authentication,
        users_in_manifest: @users_in_manifest,
        verify_multidigest_path: verify_multidigest_path,
        preferred_cpi_api_version: @dummy_cpi_api_version,
        use_nats_pure: @use_nats_pure,
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

      @sandbox_log_file.close unless @sandbox_log_file == STDOUT

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

    def reconfigure(options={})
      @user_authentication = options.fetch(:user_authentication, 'local')
      @config_server_enabled = options.fetch(:config_server_enabled, false)
      @test_initial_state = options.fetch(:test_initial_state, nil)
      @with_config_server_trusted_certs = options.fetch(:with_config_server_trusted_certs, true)
      @director_fix_stateful_nodes = options.fetch(:director_fix_stateful_nodes, false)
      @dns_enabled = options.fetch(:dns_enabled, true)
      @local_dns = options.fetch(:local_dns, {enabled: false, include_index: false, use_dns_addresses: false})
      @networks = options.fetch(:networks, enable_cpi_management: false)
      @nginx_service.reconfigure(options[:ssl_mode])
      @users_in_manifest = options.fetch(:users_in_manifest, true)
      @enable_post_deploy = options.fetch(:enable_post_deploy, true)
      @enable_nats_delivered_templates = options.fetch(:enable_nats_delivered_templates, false)
      @enable_cpi_resize_disk = options.fetch(:enable_cpi_resize_disk, false)
      @default_update_vm_strategy = options.fetch(:default_update_vm_strategy, ENV['DEFAULT_UPDATE_VM_STRATEGY'])
      @generate_vm_passwords = options.fetch(:generate_vm_passwords, false)
      @remove_dev_tools = options.fetch(:remove_dev_tools, false)
      @director_ips = options.fetch(:director_ips, [])
      @agent_wait_timeout = options.fetch(:agent_wait_timeout, 600)
      @keep_unreachable_vms = options.fetch(:keep_unreachable_vms, false)
      @with_incorrect_nats_server_ca = options.fetch(:with_incorrect_nats_server_ca, false)
      old_tls_enabled_value = @db_config[:tls_enabled]
      @db_config[:tls_enabled] = options.fetch(:tls_enabled, ENV['DB_TLS'] == 'true')
      @dummy_cpi_api_version = options.fetch(:dummy_cpi_api_version, 1)
      @nats_url = "nats://localhost:#{nats_port}"
      @cpi.options['nats'] = @nats_url
      @use_nats_pure = options.fetch(:use_nats_pure, false)

      setup_database(@db_config, old_tls_enabled_value)
    end

    def certificate_path
      File.join(SANDBOX_ASSETS_DIR, 'ca', 'certs', 'rootCA.pem')
    end

    def nats_certificate_paths
      {
        'ca_path' => get_nats_server_ca_path,

        'server' => {
          'certificate_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'nats', 'certificate.pem'),
          'private_key_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'nats', 'private_key'),
        },
        'clients' => {
          'director' => {
            'certificate_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'director', 'certificate.pem'),
            'private_key_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'director', 'private_key'),
          },
          'health_monitor' => {
            'certificate_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'health_monitor', 'certificate.pem'),
            'private_key_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'health_monitor', 'private_key'),
          },
          'test_client' => {
            'certificate_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'test_client', 'certificate.pem'),
            'private_key_path' => File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'test_client', 'private_key'),
          }
        }
      }
    end

    def director_nats_config
      {
        uri: "nats://localhost:#{nats_port}",
        ssl: true,
        tls: {
          :private_key_file => nats_certificate_paths['clients']['test_client']['private_key_path'],
          :cert_chain_file  => nats_certificate_paths['clients']['test_client']['certificate_path'],
          :verify_peer => true,
          :ca_file => nats_certificate_paths['ca_path'],
        }
      }
    end

    def stop_nats
      @nats_process.stop
    end

    def start_nats
      return if @nats_process.running?

      nats_template_path = File.join(SANDBOX_ASSETS_DIR, DEFAULT_NATS_CONF_TEMPLATE_NAME)
      write_in_sandbox(NATS_CONFIG, load_config_template(nats_template_path))
      write_in_sandbox(EXTERNAL_CPI_CONFIG, load_config_template(EXTERNAL_CPI_CONFIG_TEMPLATE))
      setup_nats
      @nats_process.start
      @nats_socket_connector.try_to_connect
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
        config_path: sandbox_path(EXTERNAL_CPI_CONFIG),
        env_path: ENV['PATH'],
        gem_home: ENV['GEM_HOME'],
        gem_path: ENV['GEM_PATH'],
        dummy_cpi_api_version: @dummy_cpi_api_version,
      }
    end

    def do_reset
      @cpi.kill_agents

      @director_service.stop

      clean_up_database

      FileUtils.rm_rf(blobstore_storage_dir)
      FileUtils.mkdir_p(blobstore_storage_dir)

      load_db_and_populate_blobstore(@test_initial_state) unless @test_initial_state.nil?

      unless @nats_process.running?
        @nats_process.stop
        start_nats
      end

      @config_server_service.restart(@with_config_server_trusted_certs) if @config_server_enabled

      @director_service.start(director_config)

      @uaa_service.start if @user_authentication == 'uaa'
      @nginx_service.restart_if_needed

      write_in_sandbox(EXTERNAL_CPI_CONFIG, load_config_template(EXTERNAL_CPI_CONFIG_TEMPLATE))
      @cpi.reset
    end

    def clean_up_database
      @database.drop_db
      @database.create_db
    end

    def setup_sandbox_root
      hm_template_path = File.join(SANDBOX_ASSETS_DIR, DEFAULT_HM_CONF_TEMPLATE_NAME)
      write_in_sandbox(HM_CONFIG, load_config_template(hm_template_path))
      write_in_sandbox(EXTERNAL_CPI, load_config_template(EXTERNAL_CPI_TEMPLATE))
      write_in_sandbox(EXTERNAL_CPI_CONFIG, load_config_template(EXTERNAL_CPI_CONFIG_TEMPLATE))
      expiry_template_path = File.join(SANDBOX_ASSETS_DIR, DIRECTOR_CERTIFICATE_EXPIRY_JSON_TEMPLATE_NAME)
      write_in_sandbox(DIRECTOR_CERTIFICATE_EXPIRY_JSON_CONFIG, load_config_template(expiry_template_path))
      nats_template_path = File.join(SANDBOX_ASSETS_DIR, DEFAULT_NATS_CONF_TEMPLATE_NAME)
      write_in_sandbox(NATS_CONFIG, load_config_template(nats_template_path))
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

    def setup_database(db_config, old_tls_enabled_value)
      if !@database || (db_config[:tls_enabled] != old_tls_enabled_value)
        if db_config[:type] == 'mysql'
          @database = Mysql.new(@name, Bosh::Core::Shell.new, @logger, db_config)
        else
          postgres_options = db_config.dup

          @database = Postgresql.new(@name, Bosh::Core::Shell.new, @logger, postgres_options)
        end
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
      gnatsd_path = Bosh::Dev::GnatsdManager.executable_path
      conf = File.join(sandbox_root, NATS_CONFIG)

      @nats_process = Service.new(
        %W[#{gnatsd_path} -c #{conf} -T -D ],
        {stdout: $stdout, stderr: $stderr},
        @logger
      )

      @nats_socket_connector = SocketConnector.new('nats', 'localhost', nats_port, @nats_log_path, @logger)
    end

    def get_nats_server_ca_path
      if @with_incorrect_nats_server_ca
        File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'childless_rootCA.pem')
      else
        File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'rootCA.pem')
      end
    end

    def director_certificate_expiry_json_path
      sandbox_path('director_certificate_expiry.json')
    end

    def get_nats_client_ca_certificate_path
      File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'rootCA.pem')
    end

    def get_nats_client_ca_private_key_path
      File.join(SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'rootCA.key')
    end

    attr_reader :director_tmp_path, :dns_db_path, :task_logs_dir
  end
end
