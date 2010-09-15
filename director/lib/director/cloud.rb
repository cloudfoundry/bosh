module Bosh::Director
  class Cloud

    def create_stemcell(image, cloud_properties)

    end

    def delete_stemcell(stemcell)

    end

    def create_vm(agent_id, stemcell, resource_pool, networks, disk_locality = nil)

    end

    def delete_vm(vm)

    end

    def configure_networks(vm, networks)

    end

    def attach_disk(vm, disk)

    end

    def detach_disk(vm, disk)

    end

    def create_disk(size, vm_locality = nil)

    end

    def delete_disk(disk)

    end

    def validate_deployment(old_manifest, new_manifest)

    end

  end
end