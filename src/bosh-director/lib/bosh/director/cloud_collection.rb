module Bosh::Director
  class CloudCollection
    attr_reader :clouds

    def initialize(clouds, logger)
      @clouds = clouds
      @logger = logger
    end

    def delete_stemcell(stemcell_id)
      call_method_for_clouds(:delete_stemcell, stemcell_id)
    end

    def delete_vm(vm_id)
      call_method_for_clouds(:delete_vm, vm_id)
    end

    def has_vm(vm_id)
      check_method_for_clouds(:has_vm, vm_id)
    end

    def has_disk(disk_id)
      check_method_for_clouds(:has_disk, disk_id)
    end

    def reboot_vm(vm_id)
      call_method_for_clouds(:reboot_vm, vm_id)
    end

    def delete_disk(disk_id)
      call_method_for_clouds(:delete_disk, disk_id)
    end

    def attach_disk(vm_id, disk_id)
      call_method_for_clouds(:attach_disk, vm_id, disk_id)
    end

    def set_disk_metadata(disk_cid, metadata)
      call_method_for_clouds(:set_disk_metadata, disk_cid, metadata)
    end

    def delete_snapshot(snapshot_id)
      call_method_for_clouds(:delete_snapshot, snapshot_id)
    end

    def detach_disk(vm_id, disk_id)
      call_method_for_clouds(:detach_disk, vm_id, disk_id)
    end

    def ==(other_collection)
      clouds == other_collection.clouds
    end

    private

    def call_method_for_clouds(method, *args)
      clouds.each do |cloud|
        begin
          cloud[:cpi].send(method, *args)
        rescue Bosh::Clouds::NotImplemented => e
          @logger.debug("CPI '#{cloud[:name]}' doesn't implement this method, trying other CPIs", e.inspect)
        end
      end
    end

    def check_method_for_clouds(method, *args)
      clouds.each do |cloud|
        cloud_result = cloud[:cpi].send(method, *args)
        return true if cloud_result
      end
      return false
    end
  end
end
