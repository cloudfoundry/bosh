module Bosh::Director
  class Config

    class << self

      attr_accessor :base_dir
      attr_accessor :logger
      attr_accessor :cloud
      attr_accessor :redis_options
      attr_accessor :pubsub_redis
      attr_accessor :blobstore

      def configure(config)
        @base_dir = config["dir"]

        @logger = Logger.new(STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)

        self.redis_options= {:host => config["redis"]["host"],
                             :port => config["redis"]["port"],
                             :password => config["redis"]["password"],
                             :logger => @logger
        }

        case config["cloud"]["plugin"]
          when "vsphere"
            @cloud = VSphereCloud.new(config["cloud"]["properties"])
          else
            raise "Could not find Cloud Provider Plugin: #{config["cloud"]["plugin"]}"
        end
      end

      def redis_options=(options)
        @redis_options = options
        @pubsub_redis = PubsubRedis.new(@redis_options)
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