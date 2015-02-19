require 'ostruct'

module VSphereCloud
  class DiskProvider
    def initialize(virtual_disk_manager, datacenter, resources, disk_path, client)
      @virtual_disk_manager = virtual_disk_manager
      @datacenter = datacenter
      @resources = resources
      @disk_path = disk_path
      @client = client
    end

    def create(disk_size_in_kb, host_info)
      datastore = find_datastore(disk_size_in_kb, host_info)
      disk_uuid = "disk-#{SecureRandom.uuid}"

      disk_spec = VimSdk::Vim::VirtualDiskManager::FileBackedVirtualDiskSpec.new
      disk_spec.disk_type = 'preallocated'
      disk_spec.capacity_kb = disk_size_in_kb
      disk_spec.adapter_type = 'lsiLogic'

      disk_path = path(datastore, disk_uuid)

      task = @virtual_disk_manager.create_virtual_disk(
        disk_path,
        @datacenter,
        disk_spec
      )
      @client.wait_for_task(task)

      Disk.new(disk_uuid, disk_size_in_kb, datastore, disk_path)
    end

    def find(disk_uuid, cluster)
      cluster.persistent_datastores.merge(cluster.shared_datastores).each do |_, datastore|
        disk_path = path(datastore, disk_uuid)
        disk_size_in_kb = get_disk_size_in_kb(disk_path)
        if disk_size_in_kb != nil
          return Disk.new(disk_uuid, disk_size_in_kb, datastore, disk_path)
        end
      end

      raise Bosh::Clouds::DiskNotFound, "Could not find disk with id #{disk_uuid}"
    end

    private

    def path(datastore, disk_uuid)
      "[#{datastore.name}] #{@disk_path}/#{disk_uuid}.vmdk"
    end

    def find_datastore(disk_size, host_info)
      datastore = @resources.place_persistent_datastore(@datacenter.name, host_info['cluster'], disk_size)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true), "Not enough persistent space on cluster #{host_info['cluster']}, #{@disk_size}"
      end

      # Sanity check, verify that the vm's host can access this datastore
      unless host_info['datastores'].include?(datastore.name)
        raise "Datastore not accessible to host, #{datastore.name}, #{host_info['datastores']}"
      end

      datastore
    end

    def get_disk_size_in_kb(disk_path)
      disk_geometry = @virtual_disk_manager.query_virtual_disk_geometry(
        disk_path,
        @datacenter
      )

      disk_geometry.cylinder * disk_geometry.head * disk_geometry.sector / 512
    rescue VimSdk::SoapError
      nil
    end
  end

  class Disk < Struct.new(:uuid, :size_in_kb, :datastore, :path); end
end
