module Bosh::Director
  class Config

    class << self

      attr_accessor :base_dir
      attr_accessor :logger
      attr_accessor :redis_options

      def configure(config)
        @base_dir = config["dir"]

        @logger = Logger.new(config["logging"]["file"] || STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)

        self.redis_options= {
          :host     => config["redis"]["host"],
          :port     => config["redis"]["port"],
          :password => config["redis"]["password"],
          :logger   => @logger
        }

        @cloud_options = config["cloud"]
        @blobstore_options = config["blobstore"]

        @pubsub_redis = nil
        @cloud = nil
        @blobstore = nil

        @lock = Mutex.new
      end

      def blobstore
        @lock.synchronize do
          if @blobstore.nil?
            @blobstore = Bosh::Blobstore::Client.create(@blobstore_options["plugin"], @blobstore_options["properties"])
          end
        end
        @blobstore
      end

      def pubsub_redis
        @lock.synchronize do
          if @pubsub_redis.nil?
            @pubsub_redis = PubsubRedis.new(@redis_options)
          end
        end
        @pubsub_redis
      end

      def cloud
        @lock.synchronize do
          if @cloud.nil?
            case @cloud_options["plugin"]
            when "vsphere"
              @cloud = Clouds::VSphere.new(@cloud_options["properties"])
            when "dummy"
              @cloud = DummyCloud.new(@cloud_options["properties"])
            else
              raise "Could not find Cloud Provider Plugin: #{@cloud_options["plugin"]}"
            end
          end
        end
        @cloud
      end

      def redis_options=(options)
        @redis_options = options
        @pubsub_redis = nil
      end

      def redis
        threaded[:redis] ||= Redis.new(@redis_options)
      end

      def threaded
        Thread.current[:bosh] ||= {}
      end

    end

  end
end
