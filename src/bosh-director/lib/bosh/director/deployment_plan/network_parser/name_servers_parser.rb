module Bosh::Director
  module DeploymentPlan
    module NetworkParser
      class NameServersParser
        include ValidationHelper

        def parse(network, subnet_properties)
          dns_spec = safe_property(subnet_properties, 'dns', :class => Array, :optional => true)

          servers = nil

          if dns_spec
            servers = []
            dns_spec.each do |dns|
               dns = Bosh::Director::IpAddrOrCidr.new(dns)
              unless dns.count == 1
                raise NetworkInvalidDns,
                      "Invalid DNS for network '#{network}': must be a single IP"
              end

              servers << dns.base_addr
            end
          end

          servers
        end
      end
    end
  end
end