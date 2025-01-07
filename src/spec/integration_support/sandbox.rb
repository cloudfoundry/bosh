require 'benchmark'
require 'fileutils'
require 'logging'
require 'rspec'
require 'securerandom'
require 'tmpdir'
require 'tempfile'

require 'cloud/dummy'

require 'integration_support/constants'
require 'integration_support/service'
require 'integration_support/http_endpoint_connector'
require 'integration_support/socket_connector'
require 'integration_support/workspace'
require 'integration_support/director_config'
require 'integration_support/port_provider'
require 'integration_support/config_server_service'
require 'integration_support/director_service'
require 'integration_support/nginx_service'
require 'integration_support/gnatsd_manager'
require 'integration_support/bosh_agent'
require 'integration_support/uaa_service'
require 'integration_support/verify_multidigest_manager'

module IntegrationSupport
  class Sandbox
    ROOT_CA_CERTIFICATE_PATH = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'ca', 'certs', 'rootCA.pem')

    HM_CONFIG = 'health_monitor.yml'
    DEFAULT_HM_CONF_TEMPLATE_NAME = 'health_monitor.yml.erb'

    NATS_SERVER_PID = 'nats.pid'
    NATS_CONFIG = 'nats.conf'
    DEFAULT_NATS_CONF_TEMPLATE_NAME = 'nats.conf.erb'

    DIRECTOR_CERTIFICATE_EXPIRY_JSON_CONFIG = 'director_certificate_expiry.json'.freeze
    DIRECTOR_CERTIFICATE_EXPIRY_JSON_TEMPLATE_NAME = 'director_certificate_expiry.json.erb'.freeze

    EXTERNAL_CPI = 'cpi'
    EXTERNAL_CPI_TEMPLATE = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'cpi.erb')

    EXTERNAL_CPI_CONFIG = 'cpi.json'
    EXTERNAL_CPI_CONFIG_TEMPLATE = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'cpi_config.json.erb')

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
    attr_reader :user_authentication

    attr_accessor :trusted_certs

    def self.workspace_dir
      Workspace.dir
    end

    def self.base_dir
      File.join(workspace_dir, 'client-sandbox')
    end

    def self.home_dir
      File.join(base_dir, 'home')
    end

    def self.test_release_dir
      File.join(base_dir, 'test_release')
    end

    def self.manifests_dir
      File.join(base_dir, 'manifests')
    end

    def self.links_release_dir
      File.join(base_dir, 'links_release')
    end

    def self.multidisks_release_dir
      File.join(base_dir, 'multidisks_release')
    end

    def self.fake_errand_release_dir
      File.join(base_dir, 'fake_errand_release')
    end

    def self.bosh_work_dir
      File.join(base_dir, 'bosh_work_dir')
    end

    def self.bosh_config
      File.join(base_dir, 'bosh_config.yml')
    end

    def self.blobstore_dir
      File.join(base_dir, 'release_blobstore')
    end

    def self.temp_dir
      File.join(base_dir, 'release_blobstore')
    end

    def self.from_env
      db_opts = {
        type: ENV.fetch('DB', 'postgresql'),
      }
      db_opts[:password] = ENV['DB_PASSWORD'] if ENV['DB_PASSWORD']

      new(
        db_opts,
        ENV['DEBUG'],
        ENV['TEST_ENV_NUMBER'].to_i,
      )
    end

    def self.install_dependencies
      FileUtils.mkdir_p(IntegrationSupport::Constants::INTEGRATION_BIN_DIR)
      IntegrationSupport::BoshAgent.install
      IntegrationSupport::NginxService.install
      IntegrationSupport::UaaService.install
      IntegrationSupport::ConfigServerService.install
      IntegrationSupport::VerifyMultidigestManager.install
      IntegrationSupport::GnatsdManager.install
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

      @task_logs_dir = sandbox_path('boshdir/tasks')
      @blobstore_storage_dir = sandbox_path('bosh_test_blobstore')
      @verify_multidigest_path = VerifyMultidigestManager.executable_path
      @dummy_cpi_api_version = nil

      @nats_log_path = File.join(@logs_path, 'nats.log')
      setup_nats

      @config_server_service = ConfigServerService.new(@port_provider, base_log_path, @logger, test_env_number)
      @nginx_service = NginxService.new(sandbox_root, director_port, director_ruby_port, "8443", base_log_path, @logger)

      @db_config = {
        ca_path: File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'database', 'rootCA.pem')
      }.merge(db_opts)

      setup_db_helper(@db_config)

      director_config_path = sandbox_path(DirectorService::DEFAULT_DIRECTOR_CONFIG)
      director_tmp_path = sandbox_path('boshdir')
      @director_service = DirectorService.new(
        {
          db_helper: @db_helper,
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

      start_nats

      @db_helper.create_db

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
        database: @db_helper,
        default_update_vm_strategy: @default_update_vm_strategy,
        director_fix_stateful_nodes: @director_fix_stateful_nodes,
        director_ips: @director_ips,
        dns_enabled: @dns_enabled,
        enable_cpi_resize_disk: @enable_cpi_resize_disk,
        enable_cpi_update_disk: @enable_cpi_update_disk,
        enable_nats_delivered_templates: @enable_nats_delivered_templates,
        enable_short_lived_nats_bootstrap_credentials: @enable_short_lived_nats_bootstrap_credentials,
        enable_short_lived_nats_bootstrap_credentials_compilation_vms: @enable_short_lived_nats_bootstrap_credentials_compilation_vms,
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
      }

      DirectorConfig.new(attributes, @port_provider)
    end

    def reset
      time = Benchmark.realtime { do_reset }
      @logger.info("Reset took #{time} seconds")
    end

    def reconfigure_health_monitor(erb_template=DEFAULT_HM_CONF_TEMPLATE_NAME)
      @health_monitor_process.stop
      write_in_sandbox(HM_CONFIG, load_config_template(File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, erb_template)))
      @health_monitor_process.start
    end

    def cloud_storage_dir
      sandbox_path('bosh_cloud_test')
    end

    def saved_logs_path
      File.join(Sandbox.workspace_dir, "#{@name}.log")
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

      @config_server_service.stop

      @db_helper.drop_db

      @sandbox_log_file.close unless @sandbox_log_file == STDOUT

      FileUtils.rm_rf(agent_tmp_path)
      FileUtils.rm_rf(blobstore_storage_dir)
    end

    def run
      start
      @logger.info('Sandbox running, type ctrl+c to stop')

      loop { sleep 60 }

    rescue Interrupt
      # Ignored
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
      Workspace.sandbox_root
    end

    def reconfigure(options={})
      @user_authentication = options.fetch(:user_authentication, 'local')
      @config_server_enabled = options.fetch(:config_server_enabled, false)
      @with_config_server_trusted_certs = options.fetch(:with_config_server_trusted_certs, true)
      @director_fix_stateful_nodes = options.fetch(:director_fix_stateful_nodes, false)
      @dns_enabled = options.fetch(:dns_enabled, true)
      @local_dns = options.fetch(:local_dns, {enabled: false, include_index: false, use_dns_addresses: false})
      @networks = options.fetch(:networks, enable_cpi_management: false)
      @nginx_service.reconfigure(options[:ssl_mode])
      @users_in_manifest = options.fetch(:users_in_manifest, true)
      @enable_nats_delivered_templates = options.fetch(:enable_nats_delivered_templates, false)
      @enable_short_lived_nats_bootstrap_credentials = options.fetch(:enable_short_lived_nats_bootstrap_credentials, false)
      @enable_short_lived_nats_bootstrap_credentials_compilation_vms = options.fetch(
        :enable_short_lived_nats_bootstrap_credentials_compilation_vms,
        false,
      )
      @enable_cpi_resize_disk = options.fetch(:enable_cpi_resize_disk, false)
      @enable_cpi_update_disk = options.fetch(:enable_cpi_update_disk, false)
      @default_update_vm_strategy = options.fetch(:default_update_vm_strategy, ENV['DEFAULT_UPDATE_VM_STRATEGY'])
      @generate_vm_passwords = options.fetch(:generate_vm_passwords, false)
      @remove_dev_tools = options.fetch(:remove_dev_tools, false)
      @director_ips = options.fetch(:director_ips, [])
      @agent_wait_timeout = options.fetch(:agent_wait_timeout, 600)
      @keep_unreachable_vms = options.fetch(:keep_unreachable_vms, false)
      @with_incorrect_nats_server_ca = options.fetch(:with_incorrect_nats_server_ca, false)
      @dummy_cpi_api_version = options.fetch(:dummy_cpi_api_version, 1)
      @nats_url = "nats://localhost:#{nats_port}"
      @cpi.options['nats'] = @nats_url

      setup_db_helper(@db_config)
    end

    def certificate_path
      ROOT_CA_CERTIFICATE_PATH
    end

    def nats_certificate_paths
      {
        'ca_path' => get_nats_server_ca_path,

        'server' => {
          'certificate_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'nats', 'certificate.pem'),
          'private_key_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'nats', 'private_key'),
        },
        'clients' => {
          'director' => {
            'certificate_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'director', 'certificate.pem'),
            'private_key_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'director', 'private_key'),
          },
          'health_monitor' => {
            'certificate_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'health_monitor', 'certificate.pem'),
            'private_key_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'health_monitor', 'private_key'),
          },
          'test_client' => {
            'certificate_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'test_client', 'certificate.pem'),
            'private_key_path' => File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'test_client', 'private_key'),
          }
        }
      }
    end

    def director_nats_config
      tls_context = OpenSSL::SSL::SSLContext.new
      tls_context.ssl_version = :TLSv1_2
      tls_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

      tls_context.key = OpenSSL::PKey::RSA.new(File.open(nats_certificate_paths['clients']['test_client']['private_key_path']))
      tls_context.cert = OpenSSL::X509::Certificate.new(File.open(nats_certificate_paths['clients']['test_client']['certificate_path']))
      tls_context.ca_file = nats_certificate_paths['ca_path']

      {
          servers: Array.new(1, "nats://localhost:#{nats_port}"),
          dont_randomize_servers: true,
          max_reconnect_attempts: 4,
          reconnect_time_wait: 2,
          reconnect: true,
          tls: {
              context: tls_context,
          },
      }
    end

    def stop_nats
      @nats_process.stop
    end

    def start_nats
      return if @nats_process.running?

      nats_template_path = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, DEFAULT_NATS_CONF_TEMPLATE_NAME)
      write_in_sandbox(NATS_CONFIG, load_config_template(nats_template_path))
      write_in_sandbox(EXTERNAL_CPI_CONFIG, load_config_template(EXTERNAL_CPI_CONFIG_TEMPLATE))
      setup_nats
      @nats_process.start
      @nats_socket_connector.try_to_connect
      write_in_sandbox(NATS_SERVER_PID, @nats_process.pid)
    end

    private

    def external_cpi_config
      {
        name: 'test-cpi',
        exec_path: File.join(IntegrationSupport::Constants::BOSH_REPO_SRC_DIR, 'bosh-director', 'bin', 'dummy_cpi'),
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

      stop_nats if @nats_process.running?
      start_nats

      @config_server_service.restart(@with_config_server_trusted_certs) if @config_server_enabled

      @director_service.start(director_config)

      @nginx_service.restart_if_needed

      write_in_sandbox(EXTERNAL_CPI_CONFIG, load_config_template(EXTERNAL_CPI_CONFIG_TEMPLATE))
      @cpi.reset
    end

    def clean_up_database
      @logger.info("Drop database '#{@db_helper.connection_string}'")
      @db_helper.drop_db
      @logger.info("Create database '#{@db_helper.connection_string}'")
      @db_helper.create_db
    end

    def setup_sandbox_root
      hm_template_path = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, DEFAULT_HM_CONF_TEMPLATE_NAME)
      write_in_sandbox(HM_CONFIG, load_config_template(hm_template_path))
      write_in_sandbox(EXTERNAL_CPI, load_config_template(EXTERNAL_CPI_TEMPLATE))
      write_in_sandbox(EXTERNAL_CPI_CONFIG, load_config_template(EXTERNAL_CPI_CONFIG_TEMPLATE))
      expiry_template_path = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, DIRECTOR_CERTIFICATE_EXPIRY_JSON_TEMPLATE_NAME)
      write_in_sandbox(DIRECTOR_CERTIFICATE_EXPIRY_JSON_CONFIG, load_config_template(expiry_template_path))
      nats_template_path = File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, DEFAULT_NATS_CONF_TEMPLATE_NAME)
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

    def setup_db_helper(db_config)
      @db_helper ||=
        begin
          db_options = db_config.dup
          db_options[:name] = @name
          SharedSupport::DBHelper.build(db_options: db_options)
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
      nats_server_conf_path = File.join(sandbox_root, NATS_CONFIG)

      @nats_process = Service.new(
        %W[#{nats_server_executable_path} -c #{nats_server_conf_path} -T -D ],
        {stdout: $stdout, stderr: $stderr},
        @logger
      )

      @nats_socket_connector = SocketConnector.new('nats', 'localhost', nats_port, @nats_log_path, @logger)
    end

    def get_nats_server_ca_path
      if @with_incorrect_nats_server_ca
        File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'childless_rootCA.pem')
      else
        File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'rootCA.pem')
      end
    end

    def director_certificate_expiry_json_path
      sandbox_path('director_certificate_expiry.json')
    end

    def get_nats_client_ca_certificate_path
      File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'rootCA.pem')
    end

    def get_nats_client_ca_private_key_path
      File.join(IntegrationSupport::Constants::SANDBOX_ASSETS_DIR, 'nats_server', 'certs', 'rootCA.key')
    end

    def nats_server_executable_path
      IntegrationSupport::GnatsdManager.executable_path
    end

    def nats_server_pid_path
      File.join(sandbox_root, NATS_SERVER_PID)
    end

    def uaa_ca_cert_path
      IntegrationSupport::UaaService::ROOT_CERT
    end

    attr_reader :director_tmp_path, :task_logs_dir
  end
end

RSpec.configure do |config|
  tmp_dir = nil

  config.before do
    FileUtils.mkdir_p(IntegrationSupport::Sandbox.workspace_dir)
    tmp_dir = Dir.mktmpdir('spec-', IntegrationSupport::Sandbox.workspace_dir)

    allow(Dir).to receive(:tmpdir).and_return(tmp_dir)
  end

  config.after do |example|
    if example.exception
      puts "> Spec failed: #{example.location}"
      puts "> Test tmpdir: #{tmp_dir}\n"
      puts "#{example.exception.message}\n"
      puts '> ---------------'
    else
      FileUtils.rm_rf(tmp_dir) unless tmp_dir.nil?
    end
  end
end
