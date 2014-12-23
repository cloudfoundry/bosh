require 'cloud/vsphere/resources/disk/disk_config'

module VSphereCloud
  class PersistentDisk
    def initialize(disk_cid, cloud_searcher, resources, client, logger)
      @model = Models::Disk.first(uuid: disk_cid)
      raise "Disk not found: #{disk_cid}" if @model.nil?

      @cloud_searcher = cloud_searcher
      @resources = resources
      @client = client
      @logger = logger
    end

    def create_spec(destination_datacenter_name, host_info, controller_key, copy_disks)
      create_disk = false

      if disk_exists?
        if disk_in_correct_datacenter?(destination_datacenter_name, host_info)
          @logger.info("Disk already in the right datastore #{destination_datacenter_name} #{@model.datastore}")

          persistent_datastore = @resources.persistent_datastore(destination_datacenter_name, host_info['cluster'], @model.datastore)
        else
          @logger.info("Disk needs to move from #{destination_datacenter_name} #{@model.datastore}")

          persistent_datastore = find_datastore(destination_datacenter_name, host_info, @model.size.to_i)
          move_disk(persistent_datastore, host_info, copy_disks)
          update(persistent_datastore.name, destination_datacenter_name)
        end
      else
        @logger.info('Need to create disk')

        create_disk = true
        persistent_datastore = find_datastore(destination_datacenter_name, host_info, @model.size.to_i)
        update(persistent_datastore.name, destination_datacenter_name)
      end

      DiskConfig.new(persistent_datastore, filename, controller_key, @model.size.to_i).
        spec(independent: true, create: create_disk)
    end

    private

    def filename
      "#{@model.path}.vmdk"
    end

    def disk_in_correct_datacenter?(destination_datacenter_name, host_info)
      (@model.datacenter == destination_datacenter_name &&
        @resources.validate_persistent_datastore(destination_datacenter_name, @model.datastore) &&
        host_info['datastores'].include?(@model.datastore))
    end

    def find_datastore(datacenter_name, host_info, disk_size)
      # Find datastore
      datastore = @resources.place_persistent_datastore(datacenter_name, host_info['cluster'], disk_size)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true), "Not enough persistent space on cluster #{host_info['cluster']}, #{disk_size}"
      end

      # Sanity check, verify that the vm's host can access this datastore
      unless host_info['datastores'].include?(datastore.name)
        raise "Datastore not accessible to host, #{datastore.name}, #{host_info['datastores']}"
      end
      datastore
    end

    def update(persistent_datastore_name, new_datacenter_name)
      # Need to create disk
      @model.datacenter = new_datacenter_name
      @model.datastore = persistent_datastore_name
      datacenter_disk_path = @resources.datacenters[new_datacenter_name].disk_path
      @model.path = "[#{@model.datastore}] #{datacenter_disk_path}/#{@model.uuid}"
      @model.save
    end

    def move_disk(destination_datastore, host_info, copy_disks)
      source_datacenter = @client.find_by_inventory_path(@model.datacenter)
      disk_path = @resources.datacenters[@model.datacenter].disk_path

      destination_path = "[#{destination_datastore.name}] #{disk_path}/#{@model.uuid}"
      @logger.info("Moving #{@model.datacenter}/#{@model.path} to #{destination_datastore.name}/#{destination_path}")

      if copy_disks
        @client.copy_disk(source_datacenter, @model.path, host_info['datacenter'], destination_path)
        @logger.info('Copied disk successfully')
      else
        @client.move_disk(source_datacenter, @model.path, host_info['datacenter'], destination_path)
        @logger.info('Moved disk successfully')
      end
    end

    def disk_exists?
      @model.path
    end
  end
end
