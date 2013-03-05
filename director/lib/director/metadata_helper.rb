module Bosh
  module Director
    module MetadataHelper

      def update_vm_metadata(vm, metadata = {})
        if Config.cloud.respond_to?(:set_vm_metadata)
          metadata[:deployment] = vm.deployment.name

          if vm.instance
            metadata[:job] = vm.instance.job
            metadata[:index] = vm.instance.index.to_s
          end

          Config.cloud.set_vm_metadata(vm.cid, metadata)
        end
      rescue Bosh::Clouds::NotImplemented => e
        Config.logger.debug(e)
      end

    end
  end
end
