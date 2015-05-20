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

    def create(disk_size_in_mb, cluster)
      if cluster
        datastore = @resources.pick_persistent_datastore_in_cluster(cluster.name, disk_size_in_mb)
      else
        datastore = @datacenter.pick_persistent_datastore(disk_size_in_mb)
      end
      disk_cid = "disk-#{SecureRandom.uuid}"
      @logger.debug("Creating disk '#{disk_cid}' in datastore '#{datastore.name}'")

      @client.create_disk(@datacenter, datastore, disk_cid, @disk_path, disk_size_in_mb)
    end

    def find_and_move(disk_cid, cluster, datacenter, accessible_datastores)
      disk = find(disk_cid)
      return disk if accessible_datastores.include?(disk.datastore.name)

      destination_datastore = @resources.pick_persistent_datastore_in_cluster(cluster.name, disk.size_in_mb)

      unless accessible_datastores.include?(destination_datastore.name)
        raise "Datastore '#{destination_datastore.name}' is not accessible to cluster '#{cluster.name}'"
      end

      destination_path = path(destination_datastore, disk_cid)
      @logger.info("Moving #{disk.path} to #{destination_path}")
      @client.move_disk(datacenter, disk.path, datacenter, destination_path)
      @logger.info('Moved disk successfully')
      Resources::Disk.new(disk_cid, disk.size_in_mb, destination_datastore, destination_path)
    end

    def find(disk_cid)
      persistent_datastores = @datacenter.persistent_datastores
      @logger.debug("Looking for disk #{disk_cid} in datastores: #{persistent_datastores}")
      persistent_datastores.each do |_, datastore|
        disk = @client.find_disk(disk_cid, datastore, @disk_path)
        return disk unless disk.nil?
      end

      raise Bosh::Clouds::DiskNotFound.new(false), "Could not find disk with id '#{disk_cid}'"
    end

    private

    def path(datastore, disk_cid)
      "[#{datastore.name}] #{@disk_path}/#{disk_cid}.vmdk"
    end
  end
end
