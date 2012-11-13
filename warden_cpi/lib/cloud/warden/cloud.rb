
module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    DEFAULT_WARDEN_SOCK = "/tmp/warden.sock"

    attr_accessor :logger

    ##
    # Initialize BOSH Warden CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @logger = Bosh::Clouds::Config.logger

      @agent_properties = options["agent"] || {}
      @warden_properties = options["warden"] || {}

      @disk_manager = DiskManager.new(options["disk"])

      setup_warden
    end

    def create_stemcell(image_path, cloud_properties)
      # TODO to be implemented
      not_used(cloud_properties)

      stemcell_uuid
    end

    def delete_stemcell(stemcell_id)
      # TODO to be implemented
    end

    def create_vm(agent_id, stemcell_id, resource_pool,
                  networks, disk_locality = nil, env = nil)
      not_used(resource_pool)
      not_used(disk_locality)
      not_used(env)

      # TODO to be implemented

      vm_uuid
    end

    def delete_vm(vm_id)
      # TODO to be implemented
    end

    def reboot_vm(vm_id)
      # no-op
    end

    def configure_networks(vm_id, networks)
      # no-op
    end

    ##
    # Creates a new disk image
    # @param [Integer] size disk size in MiB
    # @param [String] vm_locality not be used in warden cpi
    # @raise [Bosh::Clouds::NoDiskSpace] if system has not enough free space
    # @raise [Bosh::Clouds::CloudError] when meeting internal error
    # @return [String] disk id
    def create_disk(size, vm_locality = nil)
      @disk_manager.create_disk(size)
    end

    ##
    # Delete a disk image
    # @param [String] disk_id
    # @return nil
    def delete_disk(disk_id)
      # TODO to be implemented
    end

    ##
    # Attach a disk image to a vm
    # @param [String] vm_id warden container handle
    # @param [String] disk_id disk id
    # @return nil
    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    ##
    # Detach a disk image from a vm
    # @param [String] vm_id warden container handle
    # @param [String] disk_id disk id
    # @return nil
    def detach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

    def validate_deployment(old_manifest, new_manifest)
      # no-op
    end

    private

    def not_used(var)
      # no-op
    end

    def setup_warden
      @warden_unix_path = @warden_properties["unix_domain_path"] || DEFAULT_WARDEN_SOCK

      @client = Warden::Client.new(@warden_unix_path)
    end

  end
end
