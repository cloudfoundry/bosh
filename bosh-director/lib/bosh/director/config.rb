# Copyright (c) 2009-2012 VMware, Inc.

require 'fileutils'

module Bosh::Director

  # We are in the slow painful process of extracting all of this class-level
  # behavior into instance behavior, much of it on the App class. When this
  # process is complete, the Config will be responsible only for maintaining
  # configuration information - not holding the state of the world.

  class Config
    class << self
      include DnsHelper

      CONFIG_OPTIONS = [
        :base_dir,
        :cloud_options,
        :db,
        :dns,
        :dns_db,
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
        :uuid,
        :current_job,
        :encryption,
        :fix_stateful_nodes,
        :enable_snapshots,
        :max_vm_create_tries,
      ]

      CONFIG_OPTIONS.each do |option|
        attr_accessor option
      end

      attr_reader :db_config

      def clear
        CONFIG_OPTIONS.each do |option|
          self.instance_variable_set("@#{option}".to_sym, nil)
        end

        Thread.list.each do |thr|
          thr[:bosh] = nil
        end

        @blobstore = nil
        @compiled_package_cache = nil
        @nats = nil
        @nats_rpc = nil
        @cloud = nil
      end

      def configure(config)
        @max_vm_create_tries = Integer(config.fetch('max_vm_create_tries', 5))

        @base_dir = config["dir"]
        FileUtils.mkdir_p(@base_dir)

        # checkpoint task progress every 30 secs
        @task_checkpoint_interval = 30

        logging = config.fetch('logging', {})
        @log_device = Logger::LogDevice.new(logging.fetch('file', STDOUT))
        @logger = Logger.new(@log_device)
        @logger.level = Logger.const_get(logging.fetch('level', 'debug').upcase)
        @logger.formatter = ThreadFormatter.new

        # use a separate logger for redis to make it stfu
        redis_logger = Logger.new(@log_device)
        logging = config.fetch('redis', {}).fetch('logging', {})
        redis_logger_level = logging.fetch('level', 'info').upcase
        redis_logger.level = Logger.const_get(redis_logger_level)

        # Event logger supposed to be overridden per task,
        # the default one does nothing
        @event_log = EventLog::Log.new

        # by default keep only last 500 tasks in disk
        @max_tasks = config.fetch("max_tasks", 500).to_i

        @max_threads = config.fetch("max_threads", 32).to_i

        self.redis_options= {
          :host     => config["redis"]["host"],
          :port     => config["redis"]["port"],
          :password => config["redis"]["password"],
          :logger   => redis_logger
        }

        @revision = get_revision

        @logger.info("Starting BOSH Director: #{VERSION} (#{@revision})")

        @process_uuid = SecureRandom.uuid
        @nats_uri = config["mbus"]

        @cloud_options = config["cloud"]
        @compiled_package_cache_options = config["compiled_package_cache"]
        @name = config["name"] || ""

        @compiled_package_cache = nil

        @db_config = config['db']
        @db = configure_db(config["db"])
        @dns = config["dns"]
        @dns_domain_name = "bosh"
        if @dns
          @dns_db = configure_db(@dns["db"]) if @dns["db"]
          @dns_domain_name = canonical(@dns["domain_name"]) if @dns["domain_name"]
        end

        @uuid = override_uuid || retrieve_uuid
        @logger.info("Director UUID: #{@uuid}")

        @encryption = config["encryption"]
        @fix_stateful_nodes = config.fetch("scan_and_fix", {})
          .fetch("auto_fix_stateful_nodes", false)
        @enable_snapshots = config.fetch('snapshots', {}).fetch('enabled', false)

        Bosh::Clouds::Config.configure(self)

        @lock = Monitor.new
      end

      def log_dir
        File.dirname(@log_device.filename) if @log_device.filename
      end

      def use_compiled_package_cache?
        !@compiled_package_cache_options.nil?
      end

      def get_revision
        Dir.chdir(File.expand_path("../../../../../..", __FILE__))
        revision_command = "(cat REVISION 2> /dev/null || " +
            "git show-ref --head --hash=8 2> /dev/null || " +
            "echo 00000000) | head -n1"
        `#{revision_command}`.strip
      end

      def configure_db(db_config)
        patch_sqlite if db_config["adapter"] == "sqlite"

        connection_options = db_config.delete('connection_options') {{}}
        db_config.delete_if { |_, v| v.to_s.empty? }
        db_config = db_config.merge(connection_options)

        db = Sequel.connect(db_config)
        if logger
          db.logger = logger
          db.sql_log_level = :debug
        end

        db
      end

      def compiled_package_cache_blobstore
        @lock.synchronize do
          if @compiled_package_cache_blobstore.nil? && use_compiled_package_cache?
            provider = @compiled_package_cache_options["provider"]
            options = @compiled_package_cache_options["options"]
            @compiled_package_cache_blobstore = Bosh::Blobstore::Client.safe_create(provider, options)
          end
        end
        @compiled_package_cache_blobstore
      end

      def compiled_package_cache_provider
        use_compiled_package_cache? ? @compiled_package_cache_options["provider"] : nil
      end

      def cloud_type
        if @cloud_options
          @cloud_options["plugin"]
        end
      end

      def cloud
        @lock.synchronize do
          if @cloud.nil?
            plugin = @cloud_options["plugin"]
            properties = @cloud_options["properties"]
            @cloud = Bosh::Clouds::Provider.create(plugin, properties)
          end
        end
        @cloud
      end

      def logger=(logger)
        @logger = logger
        redis_options[:logger] = @logger
        if redis?
          redis.client.logger = @logger
        end
      end

      def job_cancelled?
        @current_job.task_checkpoint if @current_job
      end
      alias_method :task_checkpoint, :job_cancelled?


      def redis_options
        @redis_options ||= {}
      end

      def redis_options=(options)
        @redis_options = options
      end

      def cloud_options=(options)
        @lock.synchronize do
          @cloud_options = options
          @cloud = nil
        end
      end

      def nats
        @lock.synchronize do
          if @nats.nil?
            @nats = NATS.connect(:uri => @nats_uri, :autostart => false)
          end
        end
        @nats
      end

      def nats_rpc
        @lock.synchronize do
          if @nats_rpc.nil?
            @nats_rpc = NatsRpc.new
          end
        end
        @nats_rpc
      end

      def redis
        threaded[:redis] ||= Redis.new(redis_options)
      end

      def redis?
        !threaded[:redis].nil?
      end

      def dns_enabled?
        !@dns_db.nil?
      end

      def encryption?
        @encryption
      end

      def threaded
        Thread.current[:bosh] ||= {}
      end

      def patch_sqlite
        return if @patched_sqlite
        @patched_sqlite = true

        require "sequel"
        require "sequel/adapters/sqlite"

        Sequel::SQLite::Database.class_eval do
          def connect(server)
            opts = server_opts(server)
            opts[:database] = ':memory:' if blank_object?(opts[:database])
            db = ::SQLite3::Database.new(opts[:database])
            db.busy_handler do |retries|
              Bosh::Director::Config.logger.debug "SQLITE BUSY, retry ##{retries}"
              sleep(0.1)
              retries < 20
            end

            connection_pragmas.each { |s| log_yield(s) { db.execute_batch(s) } }

            class << db
              attr_reader :prepared_statements
            end
            db.instance_variable_set(:@prepared_statements, {})

            db
          end
        end
      end

      def retrieve_uuid
        directors = Bosh::Director::Models::DirectorAttribute.all
        director = directors.first

        if directors.size > 1
          @logger.warn("More than one UUID stored in director table, using #{director.uuid}")
        end

        unless director
          director = Bosh::Director::Models::DirectorAttribute.new
          director.uuid = gen_uuid
          director.save
          @logger.info("Generated director UUID #{director.uuid}")
        end

        director.uuid
      end

      def override_uuid
        new_uuid = nil

        if File.exists?(state_file)
          open(state_file, 'r+') do |file|

            # lock before read to avoid director/worker race condition
            file.flock(File::LOCK_EX)
            state = Yajl::Parser.parse(file) || {}
            # empty state file to prevent blocked processes from attempting to set UUID
            file.truncate(0)

            if state["uuid"]
              Bosh::Director::Models::DirectorAttribute.delete
              director = Bosh::Director::Models::DirectorAttribute.new
              director.uuid = state["uuid"]
              director.save
              @logger.info("Using director UUID #{state["uuid"]} from #{state_file}")
              new_uuid = state["uuid"]
            end

            # unlock after storing UUID
            file.flock(File::LOCK_UN)
          end

          FileUtils.rm_f(state_file)
        end

        new_uuid
      end

      def state_file
        File.join(base_dir, "state.json")
      end

      def gen_uuid
        SecureRandom.uuid
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

    attr_reader :hash

    private

    def initialize(hash)
      @hash = hash
    end

  end
end
