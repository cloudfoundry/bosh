module VCloudSdk
  module Xml

    class Vm < Wrapper
      def initialize(xml, ns = nil, ns_definitions = nil)
        super(xml, ns, ns_definitions)
        @logger = Config.logger
      end

      def attach_disk_link
        get_nodes("Link", {"rel" => "disk:attach",
          "type" => MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS]}, true).first
      end

      def description
        nodes = get_nodes("Description")
        return nodes unless nodes
        node = nodes.first
        return node unless node
        node.content
      end

      def description=(value)
        nodes = get_nodes("Description")
        return unless nodes
        node = nodes.first
        return unless node
        node.content = value
      end

      def detach_disk_link
        get_nodes("Link", {"rel" => "disk:detach",
          "type" => MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS]}, true).first
      end

      def edit_link
        get_nodes("Link", {"rel" => "edit"}, true).first
      end

      def reconfigure_link
        get_nodes("Link", {"rel" => "reconfigureVm"}, true).first
      end

      def insert_media_link
        get_nodes("Link", {"rel" => "media:insertMedia"}, true).first
      end

      def eject_media_link
        get_nodes("Link", {"rel" => "media:ejectMedia"}, true).first
      end

      def metadata_link
        get_nodes("Link", {"type" => MEDIA_TYPE[:METADATA]}, true).first
      end

      def name
         @root["name"]
      end

      def name=(value)
         @root["name"]= value
      end

      def hardware_section
        get_nodes("VirtualHardwareSection", nil, false,
          "http://schemas.dmtf.org/ovf/envelope/1").first
      end

      def network_connection_section
        get_nodes("NetworkConnectionSection",
          {"type" => MEDIA_TYPE[:NETWORK_CONNECTION_SECTION]}).first
      end

      # hardware modification methods

      def add_hard_disk(size_mb)
        section = hardware_section
        scsi_controller = section.scsi_controller
        unless scsi_controller
          raise ObjectNotFoundError, "No SCSI controller found for VM #{name}"
        end
        # Create a RASD item
        new_disk = WrapperFactory.create_instance("Item", nil,
          hardware_section.doc_namespaces)
        section.add_item(new_disk)
        # The order matters!
        new_disk.add_rasd(RASD_TYPES[:HOST_RESOURCE])
        new_disk.add_rasd(RASD_TYPES[:INSTANCE_ID])
        rt = RASD_TYPES[:RESOURCE_TYPE]
        new_disk.add_rasd(rt)
        new_disk.set_rasd(rt, HARDWARE_TYPE[:HARD_DISK])
        host_resource = new_disk.get_rasd(RASD_TYPES[:HOST_RESOURCE])
        host_resource[new_disk.create_qualified_name(
          "capacity", VCLOUD_NAMESPACE)] = size_mb.to_s
        host_resource[new_disk.create_qualified_name(
          "busSubType", VCLOUD_NAMESPACE)] = scsi_controller.get_rasd_content(
            RASD_TYPES[:RESOURCE_SUB_TYPE])
        host_resource[new_disk.create_qualified_name(
          "busType", VCLOUD_NAMESPACE)] = HARDWARE_TYPE[:SCSI_CONTROLLER]
      end

      def change_cpu_count(quantity)
        @logger.debug("Updating CPU count on vm #{name} to #{quantity} ")
        item = hardware_section.cpu
        item.set_rasd("VirtualQuantity", quantity)
      end

      def change_memory(mb)
        @logger.debug("Updating memory on vm #{name} to #{mb} MB")
        item = hardware_section.memory
        item.set_rasd("VirtualQuantity", mb)
      end

      def add_nic(nic_index, network_name, addressing_mode, ip = nil)
        section = hardware_section
        is_primary = hardware_section.nics.length == 0
        new_nic = Xml::NicItemWrapper.new(Xml::WrapperFactory.create_instance(
          "Item", nil, hardware_section.doc_namespaces))
        section.add_item(new_nic)
        new_nic.nic_index = nic_index
        new_nic.network = network_name
        new_nic.set_ip_addressing_mode(addressing_mode, ip)
        new_nic.is_primary = is_primary
        @logger.info("Adding NIC #{nic_index} to VM #{name} with the " +
          "following parameters: Network name: #{network_name}, " +
          "Addressing mode #{addressing_mode}, " +
          "IP address: #{ip.nil? ? "blank" : ip}")
      end

      # NIC modification methods

      def connect_nic(nic_index, network_name, addressing_mode,
          ip_address = nil)
        section = network_connection_section
        new_connection = WrapperFactory.create_instance("NetworkConnection",
          nil, network_connection_section.doc_namespaces)
        section.add_item(new_connection)
        new_connection.network_connection_index = nic_index
        new_connection.network = network_name
        new_connection.ip_address_allocation_mode = addressing_mode
        new_connection.ip_address = ip_address if ip_address
        new_connection.is_connected = true
      end

      # Deletes NIC from VM.  Accepts variable number of arguments for NICs.
      # To delete all NICs from VM use the splat operator
      # ex: delete_nic(vm, *vm.hardware_section.nics)
      def delete_nic(*nics)
        # Trying to remove a NIC without removing the network connection
        # first will cause an error.  Removing the network connection of a NIC
        # in the NetworkConnectionSection will automatically delete the NIC.
        net_conn_section = network_connection_section
        vhw_section = hardware_section
        nics.each do |nic|
          nic_index = nic.nic_index
          @logger.info("Removing NIC #{nic_index} from VM #{name}")
          net_conn_section.remove_network_connection(nic_index)
          vhw_section.remove_nic(nic_index)
        end
      end

      def set_nic_is_connected(nic_index, is_connected)
        net_conn_section = network_connection_section
        connection = net_conn_section.network_connection(nic_index)
        unless connection
          raise ObjectNotFoundError,
            "NIC #{nic_index} cannot be found on VM #{name}."
        end
        connection.is_connected = is_connected
      end

      def set_primary_nic(nic_index)
        net_conn_section = network_connection_section
        net_conn_section.primary_network_connection_index = nic_index
      end
    end

  end
end
