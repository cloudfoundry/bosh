module VCloudCloud
  module Client
    module Xml
      class NetworkConfigSection < Wrapper

        def network_configs
          get_nodes('NetworkConfig')
        end

        def add_network_config(config)
          raise "Only NetworkConfig can be added to #{self.class}" unless config.is_a? NetworkConfig
          add_child(config)
        end

        def delete_network_config(network_name)
          net_config = network_configs.find {|n| n.network_name == network_name }
          raise "Cannot delete network.  Network \"#{network_name}\" not found." if net_config.nil?
          net_config.node.remove
        end

      end
    end
  end
end