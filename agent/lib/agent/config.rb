module Bosh::Agent
  class Config
    class << self
      DEFAULT_BASE_DIR = "/var/vcap"

      CONFIG_OPTIONS = [
        :base_dir,
        :logger,
        :mbus,
        :agent_id,
        :configure,
        :blobstore,
        :blobstore_provider,
        :blobstore_options,
        :system_root,
        :infrastructure_name,
        :platform_name,
        :nats,
        :process_alerts,
        :smtp_port,
        :smtp_user,
        :smtp_password,
        :heartbeat_interval,
        :settings,
        :state
      ]

      CONFIG_OPTIONS.each do |option|
        attr_accessor option
      end

      def clear
        CONFIG_OPTIONS.each do |option|
          send("#{option}=", nil)
        end
      end

      def setup(config)
        @configure = config["configure"]

        # it is the responsibillity of the caller to make sure the dir exist
        unless log_dest = config["logging"]["file"]
          log_dest = STDOUT
        end

        @logger       = Logger.new(log_dest)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)

        @base_dir = config["base_dir"] || DEFAULT_BASE_DIR
        @agent_id = config["agent_id"]

        @mbus = config['mbus']

        @blobstore_options  = config["blobstore_options"]
        @blobstore_provider = config["blobstore_provider"]

        @infrastructure_name = config['infrastructure_name']
        @platform_name = config['platform_name']

        @system_root = config['root_dir'] || "/"

        @process_alerts = config["process_alerts"]
        @smtp_port      = config["smtp_port"]
        @smtp_user      = "vcap"
        @smtp_password  = random_password(8)

        @heartbeat_interval = config["heartbeat_interval"]

        unless @configure
          @logger.info("Configuring Agent with: #{config.inspect}")
        end

        @settings = {}

        @state = State.new(File.join(@base_dir, "bosh", "state.yml"))
      end

      def infrastructure
        @infrastructure||= Bosh::Agent::Infrastructure.new(@infrastructure_name).infrastructure
      end

      def platform
        @platform ||= Bosh::Agent::Platform.new(@platform_name).platform
      end

      def random_password(len)
        OpenSSL::Random.random_bytes(len).unpack("H*")[0]
      end

    end
  end
end
