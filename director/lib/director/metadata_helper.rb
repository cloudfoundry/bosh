module Bosh::Director
  module MetadataHelper

    def update_vm_metadata(vm, metadata = {})
      metadata[:deployment] = vm.deployment

      if vm.instance
        metadata[:job] = vm.instance.job
        metadata[:index] = vm.instance.index.to_s
      end

      Config.cloud.set_vm_metadata(vm.cid, metadata)
    rescue Exception => e
      Config.logger.debug(e)
    end

  end
end
