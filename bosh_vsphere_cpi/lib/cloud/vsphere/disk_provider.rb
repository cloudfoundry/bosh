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

    def create(disk_size_in_mb)
      datastore = find_datastore(disk_size_in_mb)
      disk_cid = "disk-#{SecureRandom.uuid}"
      @logger.debug("Creating disk '#{disk_cid}' in datastore '#{datastore.name}'")

      disk_size_in_kb = disk_size_in_mb * 1024
      disk_spec = VimSdk::Vim::VirtualDiskManager::FileBackedVirtualDiskSpec.new
      disk_spec.disk_type = 'preallocated'
      disk_spec.capacity_kb = disk_size_in_kb
      disk_spec.adapter_type = 'lsiLogic'

      disk_path = path(datastore, disk_cid)
      create_parent_folder(disk_path)

      task = @virtual_disk_manager.create_virtual_disk(
        disk_path,
        @datacenter.mob,
        disk_spec
      )
      @client.wait_for_task(task)


      Resources::Disk.new(disk_cid, disk_size_in_kb, datastore, disk_path)
    end

    def find_and_move(disk_cid, cluster, datacenter_name, accessible_datastores)
      disk = find(disk_cid)
      return disk if accessible_datastores.include?(disk.datastore.name)

      destination_datastore =  @resources.pick_persistent_datastore_in_cluster(cluster, disk.size_in_mb)
      if destination_datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true),
          "Not enough persistent space on cluster '#{cluster.name}', requested disk size: #{disk.size_in_mb}Mb"
      end

      unless accessible_datastores.include?(destination_datastore.name)
        raise "Datastore '#{destination_datastore.name}' is not accessible to cluster '#{cluster.name}'"
      end

      destination_path = path(destination_datastore, disk_cid)
      @logger.info("Moving #{disk.path} to #{destination_path}")
      create_parent_folder(destination_path)
      @client.move_disk(datacenter_name, disk.path, datacenter_name, destination_path)
      @logger.info('Moved disk successfully')
      Resources::Disk.new(disk_cid, disk.size_in_kb, destination_datastore, destination_path)
    end

    def find(disk_cid)
      @datacenter.persistent_datastores.each do |_, datastore|
        disk_path = path(datastore, disk_cid)
        disk_size_in_kb = get_disk_size_in_kb(disk_path)
        if disk_size_in_kb != nil
          return Resources::Disk.new(disk_cid, disk_size_in_kb, datastore, disk_path)
        end
      end

      raise Bosh::Clouds::DiskNotFound, "Could not find disk with id #{disk_cid}"
    end

    private

    def path(datastore, disk_cid)
      "[#{datastore.name}] #{@disk_path}/#{disk_cid}.vmdk"
    end

    def find_datastore(disk_size_in_mb)
      cluster = @resources.pick_cluster(0, disk_size_in_mb, [])
      datastore = @resources.pick_persistent_datastore(cluster, disk_size_in_mb)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true),
          "Not enough persistent space #{disk_size_in_mb}"
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
