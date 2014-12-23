require 'cloud/vsphere/resources/disk/disk_config'

module VSphereCloud
  class PersistentDisk
    def initialize(disk_cid, cloud_searcher, resources, client, logger)
      @model = Models::Disk.first(uuid: disk_cid)
      raise "Disk not found: #{disk_cid}" if @model.nil?

      @disk_size = @model.size.to_i

      @cloud_searcher = cloud_searcher
      @resources = resources
      @client = client
      @logger = logger
    end

    def create_spec(datacenter_name, host_info, controller_key, copy_disks)
      need_to_create_disk = !disk_exists?

      destination_datacenter = @resources.datacenters[datacenter_name]

      if disk_exists?
        if disk_in_correct_datacenter?(destination_datacenter.name, host_info)
          @logger.info("Disk already in the right datastore #{destination_datacenter.name} #{@model.datastore}")

          persistent_datastore = @resources.persistent_datastore(@model.datacenter, host_info['cluster'], @model.datastore)
        else
          @logger.info("Disk needs to move from #{@model.datacenter} to #{destination_datacenter.name}")

          persistent_datastore = find_datastore(destination_datacenter, host_info)
          move_disk(persistent_datastore, destination_datacenter, copy_disks)
          update(persistent_datastore, destination_datacenter)
        end
      else
        @logger.info('Need to create disk')

        persistent_datastore = find_datastore(destination_datacenter, host_info)
        create_parent_folder(persistent_datastore.name, destination_datacenter)
        update(persistent_datastore, destination_datacenter)
      end

      DiskConfig.new(persistent_datastore, filename, controller_key, @disk_size).
        spec(independent: true, create: need_to_create_disk)
    end

    private

    def filename
      "#{@model.path}.vmdk"
    end

    def datastore_disk_path(datastore_name, datacenter)
      "[#{datastore_name}] #{datacenter.disk_path}/#{@model.uuid}"
    end

    def disk_exists?
      !!@model.path
    end

    def disk_in_correct_datacenter?(destination_datacenter_name, host_info)
      (@model.datacenter == destination_datacenter_name &&
        @resources.validate_persistent_datastore(destination_datacenter_name, @model.datastore) &&
        host_info['datastores'].include?(@model.datastore))
    end

    def find_datastore(datacenter, host_info)
      datastore = @resources.place_persistent_datastore(datacenter.name, host_info['cluster'], @disk_size)

      if datastore.nil?
        raise Bosh::Clouds::NoDiskSpace.new(true), "Not enough persistent space on cluster #{host_info['cluster']}, #{@disk_size}"
      end

      # Sanity check, verify that the vm's host can access this datastore
      unless host_info['datastores'].include?(datastore.name)
        raise "Datastore not accessible to host, #{datastore.name}, #{host_info['datastores']}"
      end

      datastore
    end

    def update(new_datastore, new_datacenter)
      # Need to create disk
      @model.datacenter = new_datacenter.name
      @model.datastore = new_datastore.name
      @model.path = datastore_disk_path(new_datastore.name, new_datacenter)
      @model.save
    end

    def move_disk(destination_datastore, destination_datacenter, copy_disks)
      source_datacenter = @client.find_by_inventory_path(@model.datacenter)
      destination_path = datastore_disk_path(destination_datastore.name, destination_datacenter)
      @logger.info("Moving #{@model.path} to #{destination_path}")

      create_parent_folder(destination_datastore.name, destination_datacenter)

      if copy_disks
        @client.copy_disk(source_datacenter, @model.path, destination_datacenter, destination_path)
        @logger.info('Copied disk successfully')
      else
        @client.move_disk(source_datacenter, @model.path, destination_datacenter, destination_path)
        @logger.info('Moved disk successfully')
      end
    end

    def create_parent_folder(datastore_name, datacenter)
      destination_folder = File.dirname(datastore_disk_path(datastore_name, datacenter))
      @client.create_datastore_folder(destination_folder, datacenter.mob)
    end
  end
end
