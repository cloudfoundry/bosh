require 'item'

module VCloudCloud
  module Client
    module Xml
      class NicItemWrapper < Item
        def initialize(item)
          super(item.node, item.namespace, item.namespace_definitions)

          # Ensure the underlying XML has all the necessary RASD elements.  This is useful
          # for NIC creation.  Should have no effect when receiving XML from VCD.
          add_rasd(RASD_TYPES[:ADDRESS_ON_PARENT]) if get_rasd(RASD_TYPES[:ADDRESS_ON_PARENT]).nil?
          add_rasd(RASD_TYPES[:CONNECTION]) if get_rasd(RASD_TYPES[:CONNECTION]).nil?
          add_rasd(RASD_TYPES[:INSTANCE_ID]) if get_rasd(RASD_TYPES[:INSTANCE_ID]).nil?

          if get_rasd(RASD_TYPES[:RESOURCE_SUB_TYPE]).nil?
            add_rasd(RASD_TYPES[:RESOURCE_SUB_TYPE])
            set_rasd(RASD_TYPES[:RESOURCE_SUB_TYPE], RESOURCE_SUB_TYPE[:VMXNET3])
          end

          if get_rasd(RASD_TYPES[:RESOURCE_TYPE]).nil?
            add_rasd(RASD_TYPES[:RESOURCE_TYPE])
            set_rasd(RASD_TYPES[:RESOURCE_TYPE], HARDWARE_TYPE[:NIC])
          end
        end

        def is_primary
          connection['primaryNetworkConnection']
        end

        def is_primary=(value)
          primary_attr = create_qualified_name('primaryNetworkConnection', VCLOUD_NAMESPACE)
          connection[primary_attr] = value.to_s
        end

        def nic_index
          get_rasd_content(RASD_TYPES[:ADDRESS_ON_PARENT])
        end

        def nic_index=(value)
          set_rasd(RASD_TYPES[:ADDRESS_ON_PARENT], value)
        end

        def ip_addressing_mode
          attr = create_qualified_name('ipAddressingMode', VCLOUD_NAMESPACE)
          connection[attr]
        end

        def set_ip_addressing_mode(mode, ip = nil)
          raise "Invalid choice for IP addressing mode." if !IP_ADDRESSING_MODE.values.include?(mode)

          raise "Cannot set IP address unless IP addressing mode is MANUAL" \
            if !ip.nil? && !ip_addressing_mode == IP_ADDRESSING_MODE[:MANUAL]

          mode_attr = create_qualified_name('ipAddressingMode', VCLOUD_NAMESPACE)
          connection[mode_attr] = mode

          ip_attr =  create_qualified_name('ipAddress', VCLOUD_NAMESPACE)
          connection[ip_attr] = !ip.nil? ? ip : ''
        end

        def mac_address
          get_rasd_content(RASD_TYPES[:ADDRESS])
        end

        def network
          connection.content
        end

        def network=(value)
          connection.content = value
        end

        private
        def connection
          get_rasd(RASD_TYPES[:CONNECTION])
        end

      end
    end
  end
end
