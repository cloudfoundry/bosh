module Bosh::Director
  class VmMetadataUpdater
    def self.build
      new(Config.cloud, {director: Config.name}, Config.logger)
    end

    def initialize(cloud, director_metadata, logger)
      @cloud = cloud
      @director_metadata = director_metadata
      @logger = logger
    end

    def update(instance, metadata)
      if @cloud.respond_to?(:set_vm_metadata)
        metadata = metadata.merge(@director_metadata)
        metadata[:deployment] = instance.deployment.name

        metadata[:id] = instance.uuid
        metadata[:job] = instance.job
        metadata[:index] = instance.index.to_s
        metadata[:name] = "#{instance.job}/#{instance.uuid}"

        metadata[:created_at] = Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ')

        @cloud.set_vm_metadata(instance.vm_cid, metadata)
      end
    rescue Bosh::Clouds::NotImplemented => e
      @logger.debug(e.inspect)
    end
  end
end
