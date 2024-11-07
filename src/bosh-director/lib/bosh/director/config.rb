require 'fileutils'
require 'logging'
require 'socket'
require 'uri'
require 'common/logging/filters'
require 'tmpdir'
require 'common/common'
require 'common/thread_formatter'

module Bosh::Director

  # We want to shift from class methods to instance methods here.

  class Config
    class << self
      attr_accessor(
        :audit_filename,
        :audit_log_path,
        :base_dir,
        :preferred_cpi_api_version,
        :current_job,
        :db,
        :default_ssh_options,
        :default_update_vm_strategy,
        :dns,
        :enable_cpi_resize_disk,
        :enable_cpi_update_disk,
        :enable_short_lived_nats_bootstrap_credentials,
        :enable_short_lived_nats_bootstrap_credentials_compilation_vms,
        :enable_snapshots,
        :enable_virtual_delete_vms,
        :event_log,
        :fix_stateful_nodes,
        :flush_arp,
        :generate_vm_passwords,
        :keep_unreachable_vms,
        :local_dns,
        :logger,
        :max_tasks,
        :tasks_retention_period,
        :tasks_deployments_retention_period,
        :max_threads,
        :max_vm_create_tries,
        :name,
        :nats_server_ca,
        :nats_uri,
        :parallel_problem_resolution,
        :process_uuid,
        :remove_dev_tools,
        :result,
        :revision,
        :task_checkpoint_interval,
        :trusted_certs,
        :uuid,
        :verify_multidigest_path,
        :version,
      )

      attr_reader(
        :blobstore_config_fingerprint,
        :cloud_options,
        :config_server,
        :config_server_enabled,
        :db_config,
        :director_ips,
        :enable_nats_delivered_templates,
        :allow_errands_on_stopped_instances,
        :ignore_missing_gateway,
        :director_certificate_expiry_json_path,
        :nats_client_ca_certificate_path,
        :nats_client_ca_private_key_path,
        :nats_client_certificate_path,
        :nats_client_private_key_path,
        :nats_config_fingerprint,
        :record_events,
        :runtime,
      )

      def clear
        self.instance_variables.each do |ivar|
          self.instance_variable_set(ivar, nil)
        end

        Thread.list.each do |thr|
          thr[:bosh] = nil
        end

        @compiled_package_blobstore = nil

        @nats_rpc = nil
      end

      def configure(config)
        @max_vm_create_tries = Integer(config.fetch('max_vm_create_tries', 5))
        @flush_arp = config.fetch('flush_arp', false)

        @base_dir = config['dir']

        # checkpoint task progress every 30 secs
        @task_checkpoint_interval = 30

        logging_config = config.fetch('logging', {})
        logging_file = ENV['BOSH_DIRECTOR_LOG_FILE'] || logging_config.fetch('file', nil)
        if logging_file
          @log_file_path = logging_file
          shared_appender = Logging.appenders.file(
            'Director',
            filename: @log_file_path,
            layout: ThreadFormatter.layout
          )
        else
          shared_appender = Logging.appenders.io(
            'Director',
            $stdout,
            layout: ThreadFormatter.layout
          )
        end

        shared_appender.add_filters(
          Bosh::Common::Logging.null_query_filter,
          Bosh::Common::Logging.query_redaction_filter,
        )

        @logger = Logging::Logger.new('Director')
        @logger.add_appenders(shared_appender)
        @logger.level = Logging.levelify(logging_config.fetch('level', 'debug'))

        @audit_log_path = config['audit_log_path']

        # Event logger supposed to be overridden per task,
        # the default one does nothing
        @event_log = EventLog::Log.new

        # by default keep only last 2000 tasks of each type in disk
        @max_tasks = config.fetch('max_tasks', 2000).to_i

        # by default keep all tasks of each type in disk if retention period is not set
        @tasks_retention_period = config.fetch('tasks_retention_period', nil)
        @tasks_deployments_retention_period = config.fetch('tasks_deployments_retention_period', nil)

        @max_threads = config.fetch('max_threads', 32).to_i

        @revision = get_revision
        @version = config['version']

        @logger.info("Starting BOSH Director: #{@version} (#{@revision})")

        @process_uuid = SecureRandom.uuid
        @nats_uri = config['mbus']
        @nats_server_ca_path = config['nats']['server_ca_path']
        @nats_client_certificate_path = config['nats']['client_certificate_path']
        @nats_client_private_key_path = config['nats']['client_private_key_path']
        @nats_client_ca_certificate_path = config['nats']['client_ca_certificate_path']
        @nats_client_ca_private_key_path = config['nats']['client_ca_private_key_path']
        @nats_server_ca = File.read(@nats_server_ca_path)
        nats_client_ca_certificate = File.read(@nats_client_ca_certificate_path)
        nats_client_ca_private_key = File.read(@nats_client_ca_private_key_path)
        @nats_config_fingerprint = Digest::SHA1.hexdigest("#{nats_client_ca_certificate}#{nats_client_ca_private_key}#{@nats_server_ca}")

        @blobstore_config_fingerprint = Digest::SHA1.hexdigest(config.fetch('blobstore').to_s)

        @director_certificate_expiry_json_path = config['director_certificate_expiry_json_path']

        @default_ssh_options = config['default_ssh_options']

        @cloud_options = config['cloud']
        agent_config = config.fetch('agent', {})
        @agent_env = agent_config.fetch('env', {}).fetch('bosh', {})

        @agent_wait_timeout = agent_config.fetch('agent_wait_timeout', 600)

        @name = config['name'] || ''

        @runtime = config.fetch('runtime', {})
        @runtime['ip'] ||= '127.0.0.1'
        @runtime['instance'] ||= 'unknown'


        @db_config = config['db']
        @db = configure_db(config['db'])
        @dns = config.fetch('dns', {})

        @local_dns_enabled = config.fetch('local_dns', {}).fetch('enabled', false)
        @local_dns_include_index = config.fetch('local_dns', {}).fetch('include_index', false)
        @local_dns_use_dns_addresses = config.fetch('local_dns', {}).fetch('use_dns_addresses', false)

        @network_lifecycle_enabled = config.fetch('networks', {}).fetch('enable_cpi_management', false)

        # UUID in config *must* only be used for tests
        @uuid = config['uuid'] || Bosh::Director::Models::DirectorAttribute.find_or_create_uuid(@logger)
        @logger.info("Director UUID: #{@uuid}")

        @fix_stateful_nodes = config.fetch('scan_and_fix', {})
          .fetch('auto_fix_stateful_nodes', false)
        @enable_snapshots = config.fetch('snapshots', {}).fetch('enabled', false)

        @trusted_certs = config['trusted_certs'] || ''
        @ignore_missing_gateway = config['ignore_missing_gateway']

        @keep_unreachable_vms = config.fetch('keep_unreachable_vms', false)
        @enable_nats_delivered_templates = config.fetch('enable_nats_delivered_templates', false)
        @enable_short_lived_nats_bootstrap_credentials = config.fetch('enable_short_lived_nats_bootstrap_credentials', true)
        @enable_short_lived_nats_bootstrap_credentials_compilation_vms = config.fetch('enable_short_lived_nats_bootstrap_credentials_compilation_vms', false)
        @allow_errands_on_stopped_instances = config.fetch('allow_errands_on_stopped_instances', false)
        @generate_vm_passwords = config.fetch('generate_vm_passwords', false)
        @remove_dev_tools = config['remove_dev_tools']
        @record_events = config.fetch('record_events', false)

        @enable_virtual_delete_vms = config.fetch('enable_virtual_delete_vms', false)

        @director_ips = Socket.ip_address_list.reject { |addr| !addr.ip? || addr.ipv4_loopback? || addr.ipv6_loopback? || addr.ipv6_linklocal? }.map { |addr| addr.ip_address }

        @config_server = config.fetch('config_server', {})
        @config_server_enabled = @config_server['enabled']

        if @config_server_enabled
          config_server_url = config_server['url']
          unless URI.parse(config_server_url).scheme == 'https'
            raise ArgumentError, "Config Server URL should always be https. Currently it is #{config_server_url}"
          end
        end

        @lock = Monitor.new

        if config['verify_multidigest_path'].nil?
          raise ArgumentError, 'Multiple Digest binary must be specified'
        end
        @verify_multidigest_path = config['verify_multidigest_path']
        @enable_cpi_resize_disk = config.fetch('enable_cpi_resize_disk', false)
        @enable_cpi_update_disk = config.fetch('enable_cpi_update_disk', false)
        @default_update_vm_strategy = config.fetch('default_update_vm_strategy', nil)
        @parallel_problem_resolution = config.fetch('parallel_problem_resolution', true)

        cpi_config = config.fetch('cpi')
        max_cpi_api_version = cpi_config.fetch('max_supported_api_version')
        @preferred_cpi_api_version = [max_cpi_api_version, cpi_config.fetch('preferred_api_version')].min
      end

      def agent_env
        @agent_env || {}
      end

      def log_director_start
        log_director_start_event('director', uuid, { version: @version })
      end

      def log_director_start_event(object_type, object_name, context = {})
        event_manager = Api::EventManager.new(record_events)
        event_manager.create_event(
          {
            user: '_director',
            action: 'start',
            object_type: object_type,
            object_name: object_name,
            context: context
          })
      end

      def root_domain
        (Config.dns || {}).fetch('domain_name', 'bosh')
      end

      def log_dir
        File.dirname(@log_file_path) if @log_file_path
      end

      def local_dns_enabled?
        !!@local_dns_enabled
      end

      def network_lifecycle_enabled?
        !!@network_lifecycle_enabled
      end

      def local_dns_include_index?
        !!@local_dns_include_index
      end

      def local_dns_use_dns_addresses?
        !!@local_dns_use_dns_addresses
      end

      def get_revision
        Dir.chdir(File.expand_path('../../../../../..', __FILE__))
        revision_command = '(cat REVISION 2> /dev/null || ' +
            'git show-ref --head --hash=8 2> /dev/null || ' +
            'echo 00000000) | head -n1'
        `#{revision_command}`.strip
      end

      def agent_wait_timeout
        @agent_wait_timeout ||= 600
      end

      def configure_db(db_config)
        connection_config = db_config.dup
        custom_connection_options = connection_config.delete('connection_options') do
          {}
        end
        tls_options = connection_config.delete('tls') do
          {}
        end

        if tls_options.fetch('enabled', false)
          certificate_paths = tls_options.fetch('cert')
          db_ca_path = certificate_paths.fetch('ca')
          db_client_cert_path = certificate_paths.fetch('certificate')
          db_client_private_key_path = certificate_paths.fetch('private_key')

          db_ca_provided = tls_options.fetch('bosh_internal').fetch('ca_provided')
          mutual_tls_enabled = tls_options.fetch('bosh_internal').fetch('mutual_tls_enabled')

          case connection_config['adapter']
            when 'mysql2'
              # http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html#label-mysql+
              connection_config['ssl_mode'] = tls_options.fetch('skip_host_verify', false) ? 'verify_ca' : 'verify_identity'
              connection_config['sslca'] = db_ca_path if db_ca_provided
              connection_config['sslcert'] = db_client_cert_path if mutual_tls_enabled
              connection_config['sslkey'] = db_client_private_key_path if mutual_tls_enabled
            when 'postgres'
              # http://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html#label-postgres
              connection_config['sslmode'] = tls_options.fetch('skip_host_verify', false) ? 'verify-ca' : 'verify-full'
              connection_config['sslrootcert'] = db_ca_path if db_ca_provided

              postgres_driver_options = {
                'sslcert' => db_client_cert_path,
                'sslkey' => db_client_private_key_path,
              }
              connection_config['driver_options'] = postgres_driver_options if mutual_tls_enabled
            else
              # intentionally blank
          end
        end

        connection_config.delete_if { |_, v| v.to_s.empty? }
        connection_config = connection_config.merge(custom_connection_options)

        Sequel.default_timezone = :utc
        db = Sequel.connect(connection_config)

        Bosh::Common.retryable(sleep: 0.5, tries: 20, on: [Exception]) do
          db.extension :connection_validator
          true
        end

        db.pool.connection_validation_timeout = -1
        if logger
          db.logger = logger
          db.sql_log_level = :debug
          db.log_connection_info = true
        end

        db
      end

      def cloud_type
        if @cloud_options
          @cloud_options['plugin'] || @cloud_options['provider']['name']
        end
      end

      def director_pool
        @director_pool ||= Socket.gethostname
      end

      def cpi_task_log
        Config.cloud_options.fetch('properties', {}).fetch('cpi_log')
      end

      def job_cancelled?
        @current_job.task_checkpoint if @current_job
      end

      alias_method :task_checkpoint, :job_cancelled?

      def cloud_options=(options)
        @lock.synchronize do
          @cloud_options = options
        end
      end

      def nats_rpc
        # double-check locking to reduce synchronization
        if @nats_rpc.nil?
          @lock.synchronize do
            if @nats_rpc.nil?
              @nats_rpc = NatsRpc.new(@nats_uri, @nats_server_ca_path, @nats_client_private_key_path, @nats_client_certificate_path)
            end
          end
        end
        @nats_rpc
      end

      def threaded
        Thread.current[:bosh] ||= {}
      end

      def generate_temp_dir
        temp_dir = Dir.mktmpdir
        ENV["TMPDIR"] = temp_dir
        FileUtils.mkdir_p(temp_dir)
        at_exit do
          begin
            if $!
              status = $!.is_a?(::SystemExit) ? $!.status : 1
            else
              status = 0
            end
            FileUtils.rm_rf(temp_dir)
          ensure
            exit status
          end
        end
        temp_dir
      end

      def load_file(path)
        Config.new(YAML.load_file(path, permitted_classes: [Symbol], aliases: true))
      end

      def load_hash(hash)
        Config.new(hash)
      end

      def stemcell_os
        director_stemcell_owner.stemcell_os
      end

      def stemcell_version
        director_stemcell_owner.stemcell_version
      end

      def director_stemcell_owner
        @director_stemcell_owner ||= DirectorStemcellOwner.new
      end

      attr_writer :director_stemcell_owner
    end

    def name
      hash['name']
    end

    def enable_pre_ruby_3_2_equal_tilde_behavior
      hash['enable_pre_ruby_3_2_equal_tilde_behavior']
    end

    def port
      hash['port']
    end

    def puma_workers
      hash['puma_workers']
    end

    def version
      hash['version']
    end

    def scheduled_jobs
      hash['scheduled_jobs'] || []
    end

    def identity_provider
      @identity_provider ||= begin
        # no fetching w defaults?
        user_management = hash['user_management']
        user_management ||= {'provider' => 'local'}
        provider_name = user_management['provider']

        providers = {
          'uaa' => Bosh::Director::Api::UAAIdentityProvider,
          'local' => Bosh::Director::Api::LocalIdentityProvider,
        }
        provider_class = providers[provider_name]

        if provider_class.nil?
          raise ArgumentError,
            "Unknown user management provider '#{provider_name}', " +
              "available providers are: #{providers.keys.join(", ")}"
        end

        Config.logger.debug("Director configured with '#{provider_name}' user management provider")
        provider_class.new(user_management[provider_name] || {})
      end
    end

    def config_server_urls
      cfg_server_url = Config.config_server['url']
      cfg_server_url ? [cfg_server_url] : []
    end

    def worker_logger
      logger = Logging::Logger.new('DirectorWorker')
      logging_config = hash.fetch('logging', {})
      worker_logging = hash.fetch('delayed_job', {}).fetch('logging', {})
      if worker_logging.has_key?('file')
        logger.add_appenders(Logging.appenders.file('DirectorWorkerFile', filename: worker_logging.fetch('file'), layout: ThreadFormatter.layout))
      else
        logger.add_appenders(Logging.appenders.stdout('DirectorWorkerIO', layout: ThreadFormatter.layout))
      end
      logger.level = Logging.levelify(logging_config.fetch('level', 'debug'))
      logger
    end

    def sync_dns_scheduler_logger
      logger = Logging::Logger.new('SyncDnsScheduler')
      logging_config = hash.fetch('logging', {})
      logger.add_appenders(Logging.appenders.stdout('SyncDnsSchedulerIO', layout: ThreadFormatter.layout))
      logger.level = Logging.levelify(logging_config.fetch('level', 'debug'))
      logger
    end

    def metrics_server_logger
      logger = Logging::Logger.new('MetricsServer')
      logging_config = hash.fetch('logging', {})
      logger.add_appenders(Logging.appenders.stdout('MetricsServerIO', layout: ThreadFormatter.layout))
      logger.level = Logging.levelify(logging_config.fetch('level', 'debug'))
      logger
    end

    def db
      Config.configure_db(hash['db'])
    end

    def cpi
      hash.dig('cloud', 'plugin')
    end

    def blobstore_config
      hash.fetch('blobstore')
    end

    def log_access_events
      hash['log_access_events']
    end

    def director_pool
      Config.director_pool
    end

    def configure_evil_config_singleton!
      Config.configure(hash)
    end

    def get_uuid_provider
      Bosh::Director::Api::DirectorUUIDProvider.new(Config)
    end

    def record_events
      hash.fetch('record_events', false)
    end

    def metrics_server_port
      opts = hash.fetch('metrics_server', {})
      opts.fetch('backend_port', 9092)
    end

    def metrics_server_enabled
      hash.fetch('metrics_server', {}).fetch('enabled', false)
    end

    def health_monitor_port
      hash.fetch('health_monitor', {}).fetch('port', 25923)
    end

    private

    attr_reader :hash

    def initialize(hash)
      @hash = hash
    end
  end
end
