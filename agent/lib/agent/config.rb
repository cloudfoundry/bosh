module Bosh::Agent
  class Config
    class << self
      attr_accessor :base_dir, :logger, :redis_options, :pubsub_redis, :blobstore, :agent_id

      def configure(config)
        @base_dir = config["dir"]
        @logger = Logger.new(STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)
        @agent_id = "not-configured"

        @redis_options = {:host => config["redis"]["host"],
                           :port => config["redis"]["port"],
                           :password => config["redis"]["password"],
                           :logger => @logger, :timeout => 0}
      end


    end
  end
end
