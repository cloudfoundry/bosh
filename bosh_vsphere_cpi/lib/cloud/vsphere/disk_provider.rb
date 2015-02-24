require 'ostruct'
require 'cloud/vsphere/resources/disk'

module VSphereCloud
  class DiskProvider
    def initialize(virtual_disk_manager, datacenter, resources, disk_path, client, logger)
      @virtual_disk_manager = virtual_disk_manager
      @datacenter = datacenter
      @resources = resources
      @disk_path = disk_path
      @client = client
      @logger = logger
    end

    def create(disk_size_in_kb)
      disk_size_in_mb = disk_size_in_kb / 1024
      datastore = find_datastore(disk_size_in_mb)
      disk_uuid = "disk-#{SecureRandom.uuid}"

      disk_spec = VimSdk::Vim::VirtualDiskManager::FileBackedVirtualDiskSpec.new
      disk_spec.disk_type = 'preallocated'
      disk_spec.capacity_kb = disk_size_in_kb
      disk_spec.adapter_type = 'lsiLogic'

      disk_path = path(datastore, disk_uuid)
      create_parent_folder(disk_path)

      task = @virtual_disk_manager.create_virtual_disk(
        disk_path,
        @datacenter.mob,
        disk_spec
      )
      @client.wait_for_task(task)

      Resources::Disk.new(disk_uuid, disk_size_in_kb, datastore, disk_path)
    end

    def find_and_move(disk_uuid, cluster, datacenter_name, accessible_datastores)
      disk = find(disk_uuid, cluster)
      return disk if accessible_datastores.include?(disk.datastore.name)

      destination_datastore =  @resources.place_persistent_datastore(datacenter_name, cluster, disk.size_in_mb)
      unless accessible_datastores.include?(destination_datastore.name)
        raise "Datastore '#{destination_datastore.name}' is not accessible to cluster '#{cluster.name}'"
      end

      destination_path = path(destination_datastore, disk_uuid)
      @logger.info("Moving #{disk.path} to #{destination_path}")
      create_parent_folder(destination_path)
      @client.move_disk(datacenter_name, disk.path, datacenter_name, destination_path)
      @logger.info('Moved disk successfully')
      Resources::Disk.new(disk_uuid, disk.size_in_kb, destination_datastore, destination_path)
    end

    private

    def find(disk_uuid, cluster)
      cluster.persistent_datastores.merge(cluster.shared_datastores).each do |_, datastore|
        disk_path = path(datastore, disk_uuid)
        disk_size_in_kb = get_disk_size_in_kb(disk_path)
        if disk_size_in_kb != nil
          return Resources::Disk.new(disk_uuid, disk_size_in_kb, datastore, disk_path)
        end
      end

      raise Bosh::Clouds::DiskNotFound, "Could not find disk with id #{disk_uuid}"
    end

    def path(datastore, disk_uuid)
      "[#{datastore.name}] #{@disk_path}/#{disk_uuid}.vmdk"
    end

    def find_datastore(disk_size_in_mb)
      datastore = @resources.pick_persistent_datastore(disk_size_in_mb)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true), "Not enough persistent space #{disk_size_in_mb}"
      end

      datastore
    end

    def get_disk_size_in_kb(disk_path)
      disk_geometry = @virtual_disk_manager.query_virtual_disk_geometry(
        disk_path,
        @datacenter.mob
      )

      disk_geometry.cylinder * disk_geometry.head * disk_geometry.sector / 512
    rescue VimSdk::SoapError
      nil
    end

    def create_parent_folder(disk_path)
      destination_folder = File.dirname(disk_path)
      @client.create_datastore_folder(destination_folder, @datacenter.mob)
    end
  end
end
