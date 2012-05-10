# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class Config

    class << self

      CONFIG_OPTIONS = [
        :base_dir,
        :cloud_options,
        :db,
        :dns_db,
        :event_log,
        :logger,
        :max_tasks,
        :name,
        :process_uuid,
        :redis_options,
        :result,
        :revision,
        :task_checkpoint_interval,
        :uuid,
        :current_job,
        :encryption
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
        @nats = nil
        @nats_rpc = nil
        @cloud = nil
      end

      def configure(config)
        @base_dir = config["dir"]
        FileUtils.mkdir_p(@base_dir)

        # checkpoint task progress every 30 secs
        @task_checkpoint_interval = 30

        @logger = Logger.new(config["logging"]["file"] || STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)
        @logger.formatter = ThreadFormatter.new

        # Event logger supposed to be overriden per task,
        # the default one does nothing
        @event_log = EventLog.new

        @max_tasks = 500 # by default keep only last 500 tasks in disk
        if config["max_tasks"]
          @max_tasks = config["max_tasks"].to_i
        end

        self.redis_options= {
          :host     => config["redis"]["host"],
          :port     => config["redis"]["port"],
          :password => config["redis"]["password"],
          :logger   => @logger
        }

        state_json = File.join(@base_dir, "state.json")
        File.open(state_json, File::RDWR|File::CREAT, 0644) do |file|
          file.flock(File::LOCK_EX)
          state = Yajl::Parser.parse(file.read) || {}
          @uuid = state["uuid"] ||= UUIDTools::UUID.random_create.to_s
          file.rewind
          file.write(Yajl::Encoder.encode(state))
          file.flush
          file.truncate(file.pos)
        end

        @revision = get_revision

        @logger.info("Starting BOSH Director: #{VERSION} (#{@revision})")

        @process_uuid = UUIDTools::UUID.random_create.to_s
        @nats_uri = config["mbus"]

        @cloud_options = config["cloud"]
        @blobstore_options = config["blobstore"]
        @name = config["name"] || ""

        @blobstore = nil

        @db = configure_db(config["db"])
        @dns_db = configure_db(config["dns"]["db"]) if config["dns"] && config["dns"]["db"]

        @encryption = config["encryption"]

        Bosh::Clouds::Config.configure(self)

        @lock = Monitor.new
      end

      def get_revision
        Dir.chdir(File.expand_path("../../../..", __FILE__))
        revision_command = "(cat REVISION 2>&1 || " +
            "git show-ref --head --hash=8 2> /dev/null || " +
            "echo 00000000) | head -n1"
        `#{revision_command}`.strip
      end

      def configure_db(db_config)
        patch_sqlite if db_config["database"].index("sqlite://") == 0

        connection_options = {}
        [:max_connections, :pool_timeout].each { |key| connection_options[key] = db_config[key.to_s] }

        db = Sequel.connect(db_config["database"], connection_options)
        db.logger = @logger
        db.sql_log_level = :debug
        db
      end

      def blobstore
        @lock.synchronize do
          if @blobstore.nil?
            @blobstore = Bosh::Blobstore::Client.create(@blobstore_options["plugin"], @blobstore_options["properties"])
          end
        end
        @blobstore
      end

      def cloud_type
        if @cloud_options
          @cloud_options["plugin"]
        end
      end

      def cloud
        @lock.synchronize do
          if @cloud.nil?
            @cloud = Bosh::Clouds::Provider.create(@cloud_options["plugin"],
                                                   @cloud_options["properties"])
          end
        end
        @cloud
      end

      def logger=(logger)
        @logger = logger
        if @redis_options
          @redis_options[:logger] = @logger
        end
        if redis?
          redis.client.logger = @logger
        end
      end

      def job_cancelled?
        @current_job.task_checkpoint if @current_job
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
        threaded[:redis] ||= Redis.new(@redis_options)
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
