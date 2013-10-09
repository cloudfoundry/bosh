module Bosh::Agent
  class Configuration
    DEFAULT_BASE_DIR = '/var/vcap'
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
      @configure = config['configure']

      # it is the responsibillity of the caller to make sure the dir exist
      logging_config = config.fetch('logging', {})
      @logger = Logger.new(logging_config.fetch('file', STDOUT))
      @logger.level = Logger.const_get(logging_config.fetch('level', 'info').upcase)

      @base_dir = config['base_dir'] || DEFAULT_BASE_DIR
      @agent_id = config['agent_id']

      @mbus = config['mbus']

      @blobstore_options = config['blobstore_options']
      @blobstore_provider = config['blobstore_provider']

      @infrastructure_name = config['infrastructure_name']
      @platform_name = config['platform_name']

      @system_root = config['root_dir'] || '/'

      @process_alerts = config['process_alerts']
      @smtp_port = config['smtp_port']
      @smtp_user = 'vcap'
      @smtp_password = random_password(8)

      @heartbeat_interval = config['heartbeat_interval']

      unless @configure
        @logger.info("Configuring Agent with: #{config.inspect}")
      end

      @settings_file = File.join(@base_dir, 'bosh', 'settings.json')

      @credentials = config['credentials']

      @settings = {}

      @state = State.new(File.join(@base_dir, 'bosh', 'state.yml'))
    end

    def infrastructure
      @infrastructure ||= Bosh::Agent::Infrastructure.new(@infrastructure_name).infrastructure
    end

    def platform
      @platform ||= Bosh::Agent::Platform.platform(@platform_name)
    end

    def random_password(len)
      OpenSSL::Random.random_bytes(len).unpack('H*')[0]
    end

    def default_ip
      ip = nil
      @state['networks'].each do |k, v|
        ip = v['ip'] if ip.nil?
        if v.key?('default')
          ip = v['ip']
        end
      end
      ip
    end
  end
end
