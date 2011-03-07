module Bosh::Agent
  class Config
    class << self
      attr_accessor :base_dir, :logger, :mbus
      attr_accessor :agent_id, :configure
      attr_accessor :blobstore, :blobstore_provider, :blobstore_options
      attr_accessor :settings

      def setup(config)
        @base_dir = config["base_dir"]
        @logger = Logger.new(STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)

        @logger.info("Configuring Agent with: #{config}")

        @agent_id = config["agent_id"]

        @configure = config["configure"]
        @mbus = config['mbus']

        # TODO: right now this will only appy the the simple blobstore type
        @blobstore_options = config["blobstore_options"]
        @blobstore_provier = config["blobstore_provider"]

        @settings = {}
      end

    end
  end
end
