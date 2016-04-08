require 'fileutils'
require 'logging'

module Bosh::Director

  # We want to shift from class methods to instance methods here.

  class Config
    class << self
      attr_accessor(
        :base_dir,
        :cloud_options,
        :db,
        :dns,
        :dns_db,
        # @todo @for-a-refactorer according to grep of "Config.dns_domain_name" I'm pretty sure this can be removed
        :dns_domain_name,
        :event_log,
        :logger,
        :max_tasks,
        :max_threads,
        :name,
        :process_uuid,
        :result,
        :revision,
        :task_checkpoint_interval,
        :trusted_certs,
        :uuid,
        :current_job,
        :encryption,
        :fix_stateful_nodes,
        :enable_snapshots,
        :max_vm_create_tries,
        :flush_arp,
        :nats_uri,
        :default_ssh_options,
        :keep_unreachable_vms,
        :enable_post_deploy,
        :generate_vm_passwords,
        :remove_dev_tools,
        :enable_virtual_delete_vms,
      )

      attr_reader(
        :db_config,
        :ignore_missing_gateway,
        :record_events,
      )

      def clear
        self.instance_variables.each do |ivar|
          self.instance_variable_set(ivar, nil)
        end

        Thread.list.each do |thr|
          thr[:bosh] = nil
        end

        @blobstore = nil

        @compiled_package_cache = nil
        @compiled_package_blobstore = nil
        @compiled_package_cache_options = nil

        @nats = nil
        @nats_rpc = nil
        @cloud = nil
      end

      def configure(config)
        @max_vm_create_tries = Integer(config.fetch('max_vm_create_tries', 5))
        @flush_arp = config.fetch('flush_arp', false)

        @base_dir = config['dir']
        FileUtils.mkdir_p(@base_dir)

        # checkpoint task progress every 30 secs
        @task_checkpoint_interval = 30

        logging_config = config.fetch('logging', {})
        if logging_config.has_key?('file')
          @log_file_path = logging_config.fetch('file')
          shared_appender = Logging.appenders.file(
            'DirectorLogFile',
            filename: @log_file_path,
            layout: ThreadFormatter.layout
          )
        else
          shared_appender = Logging.appenders.io(
            'DirectorStdOut',
            STDOUT,
            layout: ThreadFormatter.layout
          )
        end

        @logger = Logging::Logger.new('Director')
        @logger.add_appenders(shared_appender)
        @logger.level = Logging.levelify(logging_config.fetch('level', 'debug'))

        # Event logger supposed to be overridden per task,
        # the default one does nothing
        @event_log = EventLog::Log.new

        # by default keep only last 100 tasks of each type in disk
        @max_tasks = config.fetch('max_tasks', 100).to_i

        @max_threads = config.fetch('max_threads', 32).to_i

        @revision = get_revision

        @logger.info("Starting BOSH Director: #{VERSION} (#{@revision})")

        @process_uuid = SecureRandom.uuid
        @nats_uri = config['mbus']

        @default_ssh_options = config['default_ssh_options']

        @cloud_options = config['cloud']
        @compiled_package_cache_options = config['compiled_package_cache']
        @name = config['name'] || ''

        @compiled_package_cache = nil

        @db_config = config['db']
        @db = configure_db(config['db'])
        @dns = config['dns']
        if @dns && @dns['db']
          @dns_db = configure_db(@dns['db'])
          if @dns_db
            # Load these constants early.
            # These constants are not 'require'd, they are 'autoload'ed
            # in models.rb. We're seeing that in 1.9.3 that sometimes
            # the constants loaded from one thread are not visible to other threads,
            # causing failures.
            # These constants cannot be required because they are Sequel model classes
            # that refer to database configuration that is only present when the (optional)
            # powerdns job is present and configured and points to a valid DB.
            # This is an attempt to make sure the constants are loaded
            # before forking off to other threads, hopefully eliminating the errors.
            Bosh::Director::Models::Dns::Record.class
            Bosh::Director::Models::Dns::Domain.class
          end
        end

        @dns_manager = DnsManagerProvider.create
        @uuid = override_uuid || Bosh::Director::Models::DirectorAttribute.find_or_create_uuid(@logger)
        @logger.info("Director UUID: #{@uuid}")

        @encryption = config['encryption']
        @fix_stateful_nodes = config.fetch('scan_and_fix', {})
          .fetch('auto_fix_stateful_nodes', false)
        @enable_snapshots = config.fetch('snapshots', {}).fetch('enabled', false)

        @trusted_certs = config['trusted_certs'] || ''
        @ignore_missing_gateway = config['ignore_missing_gateway']

        @keep_unreachable_vms = config.fetch('keep_unreachable_vms', false)
        @enable_post_deploy = config.fetch('enable_post_deploy', false)
        @generate_vm_passwords = config.fetch('generate_vm_passwords', false)
        @remove_dev_tools = config['remove_dev_tools']
        @record_events = config.fetch('record_events', false)

        @enable_virtual_delete_vms = config.fetch('enable_virtual_delete_vms', false)

        Bosh::Clouds::Config.configure(self)

        @lock = Monitor.new
      end

      def log_dir
        File.dirname(@log_file_path) if @log_file_path
      end

      def use_compiled_package_cache?
        !@compiled_package_cache_options.nil?
      end

      def get_revision
        Dir.chdir(File.expand_path('../../../../../..', __FILE__))
        revision_command = '(cat REVISION 2> /dev/null || ' +
            'git show-ref --head --hash=8 2> /dev/null || ' +
            'echo 00000000) | head -n1'
        `#{revision_command}`.strip
      end

      def configure_db(db_config)
        connection_config = db_config.dup
        connection_options = connection_config.delete('connection_options') {{}}
        connection_config.delete_if { |_, v| v.to_s.empty? }
        connection_config = connection_config.merge(connection_options)

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
        end

        db
      end

      def compiled_package_cache_blobstore
        @lock.synchronize do
          if @compiled_package_cache_blobstore.nil? && use_compiled_package_cache?
            provider = @compiled_package_cache_options['provider']
            options = @compiled_package_cache_options['options']
            @compiled_package_cache_blobstore = Bosh::Blobstore::Client.safe_create(provider, options)
          end
        end
        @compiled_package_cache_blobstore
      end

      def compiled_package_cache_provider
        use_compiled_package_cache? ? @compiled_package_cache_options['provider'] : nil
      end

      def cloud_type
        if @cloud_options
          @cloud_options['plugin'] || @cloud_options['provider']['name']
        end
      end

      def cloud
        @lock.synchronize do
          if @cloud.nil?
            @cloud = Bosh::Clouds::Provider.create(@cloud_options, @uuid)
          end
        end
        @cloud
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
          @cloud = nil
        end
      end

      def nats_rpc
        # double-check locking to reduce synchronization
        if @nats_rpc.nil?
          @lock.synchronize do
            if @nats_rpc.nil?
              @nats_rpc = NatsRpc.new(@nats_uri)
            end
          end
        end
        @nats_rpc
      end

      def encryption?
        @encryption
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

      def override_uuid
        new_uuid = nil
        state_file = File.join(base_dir, 'state.json')

        begin
          open(state_file, 'r+') do |file|

            # Lock before read to avoid director/worker race condition
            file.flock(File::LOCK_EX)
            state = Yajl::Parser.parse(file) || {}

            # Empty state file to prevent blocked processes from attempting to set UUID
            file.truncate(0)

            if state['uuid']
              Bosh::Director::Models::DirectorAttribute.update_or_create_uuid(state['uuid'], @logger)
              @logger.info("Using director UUID #{state['uuid']} from #{state_file}")
              new_uuid = state['uuid']
            end

            # Unlock after storing UUID
            file.flock(File::LOCK_UN)
          end

          FileUtils.rm_f(state_file)

        rescue Errno::ENOENT
          # Catch race condition since another process (director/worker) might migrated the state
        end

        new_uuid
      end
    end

    class << self
      def load_file(path)
        Config.new(Psych.load_file(path))
      end

      def load_hash(hash)
        Config.new(hash)
      end
    end

    def name
      hash['name']
    end

    def port
      hash['port']
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

    def db
      Config.configure_db(hash['db'])
    end

    def blobstore_config
      hash.fetch('blobstore')
    end

    def backup_blobstore_config
      hash['backup_destination']
    end

    def log_access_events_to_syslog
      hash['log_access_events_to_syslog']
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

    private

    attr_reader :hash

    def initialize(hash)
      @hash = hash
    end
  end
end
