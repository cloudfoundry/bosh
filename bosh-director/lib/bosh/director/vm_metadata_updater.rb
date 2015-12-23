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

    def update(vm, metadata)
      if @cloud.respond_to?(:set_vm_metadata)
        metadata = metadata.merge(@director_metadata)
        metadata[:deployment] = vm.deployment.name

        if vm.instance
          metadata[:job] = vm.instance.job
          metadata[:index] = vm.instance.index.to_s
        end

        @cloud.set_vm_metadata(vm.cid, metadata)
      end
    rescue Bosh::Clouds::NotImplemented => e
      @logger.debug(e.inspect)
    end
  end
end
