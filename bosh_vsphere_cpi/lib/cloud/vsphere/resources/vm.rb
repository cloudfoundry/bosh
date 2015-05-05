module VSphereCloud
  class Resources
    class VM
      include VimSdk
      include RetryBlock

      attr_reader :mob, :cid

      def initialize(cid, mob, client, logger)
        @client = client
        @mob = mob
        @cid = cid
        @logger = logger
      end

      def inspect
        "<VM: #{@mob} / #{@cid}>"
      end

      def cluster
        cluster = cloud_searcher.get_properties(host_properties['parent'], Vim::ClusterComputeResource, 'name', ensure_all: true)
        cluster['name']
      end

      def resource_pool
        properties['resourcePool'].name
      end

      def accessible_datastores
        host_properties['datastore'].map do |store|
          ds = cloud_searcher.get_properties(store, Vim::Datastore, 'info', ensure_all: true)
          ds['info'].name
        end
      end

      def datacenter
        @client.find_parent(@mob, Vim::Datacenter)
      end

      def powered_on?
        power_state == Vim::VirtualMachine::PowerState::POWERED_ON
      end

      def devices
        properties['config.hardware.device']
      end

      def nics
        devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }
      end

      def cdrom
        devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualCdrom) }
      end

      def system_disk
        devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) }
      end

      def persistent_disks
       devices.select do |device|
          device.kind_of?(Vim::Vm::Device::VirtualDisk) &&
            device.backing.disk_mode == Vim::Vm::Device::VirtualDiskOption::DiskMode::INDEPENDENT_PERSISTENT
        end
      end

      def pci_controller
        devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualPCIController) }
      end

      def fix_device_unit_numbers(device_changes)
        controllers_available_unit_numbers = Hash.new { |h,k| h[k] = (0..15).to_a }
        devices.each do |device|
          if device.controller_key
            available_unit_numbers = controllers_available_unit_numbers[device.controller_key]
            available_unit_numbers.delete(device.unit_number)
          end
        end

        device_changes.each do |device_change|
          device = device_change.device
          if device.controller_key && device.unit_number.nil?
            available_unit_numbers = controllers_available_unit_numbers[device.controller_key]
            raise "No available unit numbers for device: #{device.inspect}" if available_unit_numbers.empty?
            device.unit_number = available_unit_numbers.shift
          end
        end
      end

      def shutdown
        @logger.debug('Waiting for the VM to shutdown')
        begin
          begin
            @mob.shutdown_guest
          rescue => e
            @logger.debug("Ignoring possible race condition when a VM has powered off by the time we ask it to shutdown: #{e.inspect}")
          end

          wait_until_off(60)
        rescue VSphereCloud::Cloud::TimeoutException
          @logger.debug('The guest did not shutdown in time, requesting it to power off')
          @client.power_off_vm(@mob)
        end
      end

      def power_off
        retry_block do
          question = properties['runtime.question']
          if question
            choices = question.choice
            @logger.info("VM is blocked on a question: #{question.text}, " +
              "providing default answer: #{choices.choice_info[choices.default_index].label}")
            @client.answer_vm(@mob, question.id, choices.choice_info[choices.default_index].key)
            power_state = cloud_searcher.get_property(@mob, Vim::VirtualMachine, 'runtime.powerState')
          else
            power_state = properties['runtime.powerState']
          end

          if power_state != Vim::VirtualMachine::PowerState::POWERED_OFF
            @logger.info("Powering off vm: #{@cid}")
            @client.power_off_vm(@mob)
          end
        end
      end

      def disk_by_cid(disk_cid)
        devices.find do |d|
          d.kind_of?(Vim::Vm::Device::VirtualDisk) &&
            d.backing.file_name.end_with?("/#{disk_cid}.vmdk")
        end
      end

      def reboot
        @mob.reboot_guest
      end

      def power_on
        @client.power_on_vm(datacenter, @mob)
      end

      def delete
        retry_block { @client.delete_vm(@mob) }
      end

      def reload
        @properties = nil
        @host_properties = nil
      end

      def wait_until_off(timeout)
        started = Time.now
        loop do
          power_state = cloud_searcher.get_property(@mob, Vim::VirtualMachine, 'runtime.powerState')
          break if power_state == Vim::VirtualMachine::PowerState::POWERED_OFF
          raise VSphereCloud::Cloud::TimeoutException if Time.now - started > timeout
          sleep(1.0)
        end
      end

      private

      def power_state
        properties['runtime.powerState']
      end

      def properties
        @properties ||= cloud_searcher.get_properties(
          @mob,
          Vim::VirtualMachine,
          ['runtime.powerState', 'runtime.question', 'config.hardware.device', 'name', 'runtime', 'resourcePool'],
          ensure: ['config.hardware.device', 'runtime']
        )
      end

      def host_properties
        @host_properties ||= cloud_searcher.get_properties(
          properties['runtime'].host,
          Vim::HostSystem,
          ['datastore', 'parent'],
          ensure_all: true
        )
      end

      def cloud_searcher
        @client.cloud_searcher
      end
    end
  end
end
