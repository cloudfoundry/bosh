# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Config
    class << self
      DEFAULT_BASE_DIR = "/var/vcap"
      DEFAULT_SSHD_MONITOR_INTERVAL = 30
      DEFAULT_SSHD_START_DELAY = 30

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
        :settings_file,
        :settings,
        :state,
        :sshd_monitor_interval,
        :sshd_start_delay,
        :sshd_monitor_enabled,
        :credentials
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

        @sshd_monitor_interval = config["sshd_monitor_interval"] || DEFAULT_SSHD_MONITOR_INTERVAL
        @sshd_start_delay = config["sshd_start_delay"] || DEFAULT_SSHD_START_DELAY
        @sshd_monitor_enabled = config["sshd_monitor_enabled"]

        unless @configure
          @logger.info("Configuring Agent with: #{config.inspect}")
        end

        @settings_file = File.join(@base_dir, 'bosh', 'settings.json')

        @credentials = config["credentials"]

        @settings = {}

        @state = State.new(File.join(@base_dir, "bosh", "state.yml"))
      end

      def infrastructure
        @infrastructure ||= Bosh::Agent::Infrastructure.new(@infrastructure_name).infrastructure
      end

      def platform
        @platform ||= Bosh::Agent::Platform.new(@platform_name).platform
      end

      def random_password(len)
        OpenSSL::Random.random_bytes(len).unpack("H*")[0]
      end

      def default_ip
        ip = nil
        @state["networks"].each do |k, v|
          ip = v["ip"] if ip.nil?
          if v.key?('default')
            ip = v["ip"]
          end
        end
        ip
      end

    end
  end
end
