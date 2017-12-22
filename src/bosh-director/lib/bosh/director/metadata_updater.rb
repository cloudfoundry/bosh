module Bosh::Director
  class MetadataUpdater
    def self.build
      new({'director' => Config.name}, Config.logger)
    end

    def initialize(director_metadata, logger)
      @director_metadata = director_metadata
      @logger = logger
    end

    def update_vm_metadata(instance, vm, metadata, factory = CloudFactory.create_with_latest_configs)
      cloud = factory.get(vm.cpi)

      if cloud.respond_to?(:set_vm_metadata)
        metadata = metadata.merge(@director_metadata)
        metadata['deployment'] = instance.deployment.name
        metadata['id'] = instance.uuid
        metadata['job'] = instance.job
        metadata['instance_group'] = instance.job
        metadata['index'] = instance.index.to_s
        metadata['name'] = "#{instance.job}/#{instance.uuid}"
        metadata['created_at'] = Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ')

        cloud.set_vm_metadata(vm.cid, metadata)
      end
    rescue Bosh::Clouds::NotImplemented => e
      @logger.debug(e.inspect)
    end

    def update_disk_metadata(cloud, disk, metadata)
      if cloud.respond_to?(:set_disk_metadata)
        metadata = metadata.merge(@director_metadata)
        metadata['deployment'] = disk.instance.deployment.name
        metadata['instance_id'] = disk.instance.uuid
        metadata['instance_index'] = disk.instance.index.to_s
        metadata['instance_group'] = "#{disk.instance.job}"
        metadata['attached_at'] = Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ')

        cloud.set_disk_metadata(disk.disk_cid, metadata)
      end
    rescue Bosh::Clouds::NotImplemented => e
       @logger.debug(e.inspect)
    end
  end
end
