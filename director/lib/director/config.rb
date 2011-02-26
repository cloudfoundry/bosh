require "monitor"

module Bosh::Director
  class Config

    class << self

      attr_accessor :base_dir
      attr_accessor :logger
      attr_accessor :uuid
      attr_accessor :db
      attr_accessor :name

      attr_reader :redis_options
      attr_reader :cloud_options

      def configure(config)
        @base_dir = config["dir"]

        @logger = Logger.new(config["logging"]["file"] || STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)
        @logger.formatter = ThreadFormatter.new

        self.redis_options= {
          :host     => config["redis"]["host"],
          :port     => config["redis"]["port"],
          :password => config["redis"]["password"],
          :logger   => @logger
        }

        @uuid = UUIDTools::UUID.random_create.to_s
        @nats_uri = config["mbus"]

        @cloud_options = config["cloud"]
        @blobstore_options = config["blobstore"]
        @name = config["name"] || ""

        @blobstore = nil
        @db = Sequel.connect(config["db"])
        @db.logger = @logger

        @lock = Monitor.new
      end

      def blobstore
        @lock.synchronize do
          if @blobstore.nil?
            @blobstore = Bosh::Blobstore::Client.create(@blobstore_options["plugin"], @blobstore_options["properties"])
          end
        end
        @blobstore
      end

      def cloud
        @lock.synchronize do
          if @cloud.nil?
            case @cloud_options["plugin"]
            when "vsphere"
              @cloud = Clouds::VSphere.new(@cloud_options["properties"])
            when "esx"
              @cloud = Clouds::Esx.new(@cloud_options["properties"])
            when "dummy"
              @cloud = DummyCloud.new(@cloud_options["properties"])
            else
              raise "Could not find Cloud Provider Plugin: #{@cloud_options["plugin"]}"
            end
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

      def threaded
        Thread.current[:bosh] ||= {}
      end

    end

  end
end
