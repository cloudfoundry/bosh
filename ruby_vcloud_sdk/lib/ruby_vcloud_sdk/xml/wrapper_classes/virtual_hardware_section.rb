module VCloudSdk
  module Xml

    class VirtualHardwareSection < Wrapper
      def add_item(item)
        system_node = get_nodes("System", nil, true, OVF).first
        system_node.node.after(item.node)
      end

      def edit_link
        get_nodes("Link", {"rel" => "edit",
          "type" => MEDIA_TYPE[:VIRTUAL_HARDWARE_SECTION]}, true).first
      end

      def cpu
        hardware.find { |h| h.get_rasd_content(RASD_TYPES[:RESOURCE_TYPE]) ==
          HARDWARE_TYPE[:CPU] }
      end

      def memory
        hardware.find { |h| h.get_rasd_content(RASD_TYPES[:RESOURCE_TYPE]) ==
          HARDWARE_TYPE[:MEMORY] }
      end

      def scsi_controller
        hardware.find { |h| h.get_rasd_content(RASD_TYPES[:RESOURCE_TYPE]) ==
          HARDWARE_TYPE[:SCSI_CONTROLLER] }
      end

      def highest_instance_id
        hardware.map{|h| h.instance_id}.max
      end

      def nics
        items = hardware.find_all {|h| h.get_rasd_content(
          RASD_TYPES[:RESOURCE_TYPE]) == HARDWARE_TYPE[:NIC] }
        items.map { |i| NicItemWrapper.new(i) }
      end

      def remove_nic(index)
        remove_hw(HARDWARE_TYPE[:NIC], index)
      end

      def remove_hw(hw_type, index)
        item = hardware.find { |h|
          h.get_rasd_content(RASD_TYPES[:RESOURCE_TYPE]) == hw_type &&
          h.get_rasd_content(RASD_TYPES[:ADDRESS_ON_PARENT]) == index }
        if item
          item.node.remove
        else
          raise ObjectNotFoundError,
            "Cannot remove hw item #{hw_type}:#{index}, does not exist."
        end
      end

      def hard_disks
        items = hardware.find_all { |h| h.get_rasd_content(
          RASD_TYPES[:RESOURCE_TYPE]) == HARDWARE_TYPE[:HARD_DISK] }
        items.map { |i| HardDiskItemWrapper.new(i) }
      end

      def hardware
        get_nodes("Item", nil, false, OVF)
      end
    end

  end
end
