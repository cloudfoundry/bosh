module Bosh::Director
  module DeploymentPlan
    module NetworkParser
      class NameServersParser

        include ValidationHelper

        def initialize
          dns_config = Config.dns || {}
          @include_power_dns_server_addr = !!Config.dns_db
          @default_server = dns_config['server']
        end

        def parse(network, subnet_properties)
          dns_spec = safe_property(subnet_properties, 'dns', :class => Array, :optional => true)

          servers = nil

          if dns_spec
            servers = []
            dns_spec.each do |dns|
              dns = NetAddr::CIDR.create(dns)
              unless dns.size == 1
                raise NetworkInvalidDns,
                      "Invalid DNS for network '#{network}': must be a single IP"
              end

              servers << dns.ip
            end
          end

          if @include_power_dns_server_addr
            return add_default_dns_server(servers)
          end

          servers
        end

        private

        # add default dns server to an array of dns servers
        def add_default_dns_server(servers)

          unless @default_server.to_s.empty? || @default_server == '127.0.0.1'
            (servers ||= []) << @default_server
            servers.uniq!
          end

          servers
        end
      end
    end
  end
end