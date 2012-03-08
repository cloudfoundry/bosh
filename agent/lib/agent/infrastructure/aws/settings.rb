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
      # Get IP address
      # Get netmask
      # XXX Use Martins abstraction
      ifconfig_str = %x[ ifconfig eth0 | egrep "inet addr:"]
      ifconfig_match = ifconfig_str.match("inet addr:([0-9.]*)\s+Bcast:([0-9.]*)\s+Mask:([0-9.]*)")
      ip = ifconfig_match[1]
      netmask = ifconfig_match[3]

      # Get gateway
      route_str = %x[route -n | egrep UG]
      route_match = route_str.match("[0-9.]*\s+([0-9.]*)\s+")
      gateway = route_match[1]

      # Get dns
      nameservers = []
      nameserver_str = %x[cat /etc/resolv.conf | egrep "nameserver"]
      nameserver_str.split("\n").each do |str|
        nameserver_match = str.match("nameserver\s+([0-9.]*)")
        nameservers << nameserver_match[1]
      end
      networks = {"apps" => {}}
      networks["apps"]["ip"] = ip
      networks["apps"]["netmask"] = netmask
      # XXX Should we return security group or some such?
      networks["apps"]["cloud_properties"] = {"name" => "dummy"}
      networks["apps"]["dns"] = nameservers
      networks["apps"]["gateway"] = gateway
      networks
    end

  end
end
