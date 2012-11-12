
module Bosh::WardenCloud
  class Cloud < Bosh::Cloud

    include Helpers

    attr_accessor :logger

    def initialize(options)
      @agent_properties = options["agent"] || {}
      @warden_properties = options["warden"]

      @client = Warden::Client.new(@warden_properties["unix_domain_path"])
    end

    def create_stemcell(image_path, cloud_properties)
      # TODO to be implemented

      SecureRandom.uuid
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

      SecureRandom.uuid
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

      disk_id = SecureRandom.uuid
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

  end
end
