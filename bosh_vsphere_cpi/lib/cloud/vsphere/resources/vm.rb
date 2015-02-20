module VSphereCloud
  class Resources
    class VM
      include VimSdk

      class TimeoutException < StandardError; end

      attr_reader :mob, :cid

      def initialize(cid, mob, client, logger)
        @client = client
        @cloud_searcher = client.cloud_searcher
        @mob = mob
        @cid = cid
        @logger = logger
      end

      def inspect
        "<VM: #{@mob} / #{@cid}>"
      end

      def cluster
        cluster = @cloud_searcher.get_properties(host_properties['parent'], Vim::ClusterComputeResource, 'name')
        cluster['name']
      end

      def accessible_datastores
        host_properties['datastore'].map do |store|
          ds = @cloud_searcher.get_properties(store, Vim::Datastore, 'info', ensure_all: true)
          ds['info'].name
        end
      end

      def devices
        @devices ||= @cloud_searcher.get_properties(@mob, Vim::VirtualMachine, ['config.hardware.device'])['config.hardware.device']
      end

      def nics
        devices.select { |device| device.kind_of?(Vim::Vm::Device::VirtualEthernetCard) }
      end

      def system_disk
        devices.find { |device| device.kind_of?(Vim::Vm::Device::VirtualDisk) }
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
        rescue TimeoutException
          @logger.debug('The guest did not shutdown in time, requesting it to power off')
          @client.power_off_vm(@mob)
        end
      end

      private

      def host_properties
        @host_properties ||= @cloud_searcher.get_properties(vm_runtime.host, Vim::HostSystem, ['datastore', 'parent'], ensure_all: true)
      end

      def vm_runtime
        @vm_runtime ||= @cloud_searcher.get_properties(@mob, Vim::VirtualMachine, ['runtime'])['runtime']
      end

      def wait_until_off(timeout)
        started = Time.now
        loop do
          power_state = @cloud_searcher.get_property(@mob, Vim::VirtualMachine, 'runtime.powerState')
          break if power_state == Vim::VirtualMachine::PowerState::POWERED_OFF
          raise TimeoutException if Time.now - started > timeout
          sleep(1.0)
        end
      end
    end
  end
end
