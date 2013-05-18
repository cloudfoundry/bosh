# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
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
        :fix_stateful_nodes
      ]

      CONFIG_OPTIONS.each do |option|
        attr_accessor option
      end

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
        @base_dir = config["dir"]
        FileUtils.mkdir_p(@base_dir)

        # checkpoint task progress every 30 secs
        @task_checkpoint_interval = 30

        logging = config.fetch('logging', {})
        log_device = Logger::LogDevice.new(logging.fetch('file', STDOUT))
        @logger = Logger.new(log_device)
        @logger.level = Logger.const_get(logging.fetch('level', 'debug').upcase)
        @logger.formatter = ThreadFormatter.new

        # use a separate logger for redis to make it stfu
        redis_logger = Logger.new(log_device)
        logging = config.fetch('redis', {}).fetch('logging', {})
        redis_logger_level = logging.fetch('level', 'info').upcase
        redis_logger.level = Logger.const_get(redis_logger_level)

        # Event logger supposed to be overridden per task,
        # the default one does nothing
        @event_log = EventLog.new

        # by default keep only last 500 tasks in disk
        @max_tasks = config.fetch("max_tasks", 500).to_i

        @max_threads = config.fetch("max_threads", 32).to_i

        self.redis_options= {
          :host     => config["redis"]["host"],
          :port     => config["redis"]["port"],
          :password => config["redis"]["password"],
          :logger   => redis_logger
        }

        state_json = File.join(@base_dir, "state.json")
        File.open(state_json, File::RDWR|File::CREAT, 0644) do |file|
          file.flock(File::LOCK_EX)
          state = Yajl::Parser.parse(file.read) || {}
          @uuid = state["uuid"] ||= SecureRandom.uuid
          file.rewind
          file.write(Yajl::Encoder.encode(state))
          file.flush
          file.truncate(file.pos)
        end

        @revision = get_revision

        @logger.info("Starting BOSH Director: #{VERSION} (#{@revision})")

        @process_uuid = SecureRandom.uuid
        @nats_uri = config["mbus"]

        @cloud_options = config["cloud"]
        @blobstore_options = config["blobstore"]

        @compiled_package_cache_options = config["compiled_package_cache"]
        @name = config["name"] || ""

        @blobstore = nil
        @compiled_package_cache = nil

        @db = configure_db(config["db"])
        @dns = config["dns"]
        @dns_domain_name = "bosh"
        if @dns
          @dns_db = configure_db(@dns["db"]) if @dns["db"]
          @dns_domain_name = canonical(@dns["domain_name"]) if @dns["domain_name"]
        end

        @encryption = config["encryption"]
        @fix_stateful_nodes = config.fetch("scan_and_fix", {})
          .fetch("auto_fix_stateful_nodes", false)

        Bosh::Clouds::Config.configure(self)

        @lock = Monitor.new
      end

      def use_compiled_package_cache?
        !@compiled_package_cache_options.nil?
      end

      def get_revision
        Dir.chdir(File.expand_path("../../../../..", __FILE__))
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

      def blobstore
        @lock.synchronize do
          if @blobstore.nil?
            provider = @blobstore_options["provider"]
            options = @blobstore_options["options"]
            @blobstore = Bosh::Blobstore::Client.create(provider, options)
          end
        end
        @blobstore
      end

      def compiled_package_cache_blobstore
        @lock.synchronize do
          if @compiled_package_cache_blobstore.nil? && use_compiled_package_cache?
            provider = @compiled_package_cache_options["provider"]
            options = @compiled_package_cache_options["options"]
            @compiled_package_cache_blobstore = Bosh::Blobstore::Client.create(provider, options)
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

    end

  end
end
