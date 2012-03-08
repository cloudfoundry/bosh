module Bosh::Agent
  class Infrastructure::Aws::Settings

    def initialize
      @settings_file = Bosh::Agent::Config.settings_file
    end

    def logger
      Bosh::Agent::Config.logger
    end

    def load_settings
      settings = Infrastructure::Aws::Registry.get_settings
      settings_json = Yajl::Encoder.encode(@settings)
      File.open(@settings_file, 'w') { |f| f.write(settings_json) }
      Bosh::Agent::Config.settings = settings
    end

    def get_network_settings
      sigar = Sigar.new
      ifconfig = sigar.net_interface_config("eth0")
      net_info = sigar.net_info

      networks = {"default" => {}}
      networks["default"]["ip"] = ifconfig.address
      networks["default"]["netmask"] = ifconfig.netmask
      networks["default"]["dns"] = [net_info.primary_dns, net_info.secondary_dns]
      networks["default"]["gateway"] = net_info.default_gateway
      networks
    end

  end
end
