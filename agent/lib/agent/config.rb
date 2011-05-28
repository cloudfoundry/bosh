module Bosh::Agent
  class Config
    class << self
      attr_accessor :base_dir, :logger, :mbus
      attr_accessor :agent_id, :configure
      attr_accessor :blobstore, :blobstore_provider, :blobstore_options
      attr_accessor :system_root, :platform_name
      attr_accessor :settings

      def setup(config)
        @configure = config["configure"]

        @logger = Logger.new(STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)

        @base_dir = config["base_dir"]
        @agent_id = config["agent_id"]

        @mbus = config['mbus']
        @blobstore_options = config["blobstore_options"]
        @blobstore_provider = config["blobstore_provider"]

        @platform_name = config['platform_name']

        @system_root = "/"

        unless @configure
          @logger.info("Configuring Agent with: #{config.inspect}")
        end

        @settings = {}
      end

      def platform
        @platform ||= Bosh::Agent::Platform.new(@platform_name).platform
      end

    end
  end
end
