
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

    def create_disk(size, vm_locality = nil)
      # vm_locality is a string, which might mean the disk_path

      disk_id = disk_uuid
      disk_path = "/tmp/disk/#{disk_id}"

      disk_id
    end

    def delete_disk(disk_id)
      # TODO to be implemented
    end

    def attach_disk(vm_id, disk_id)
      # TODO to be implemented
    end

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
