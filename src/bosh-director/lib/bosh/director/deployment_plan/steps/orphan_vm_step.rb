module Bosh::Director
  module DeploymentPlan
    module Steps
      class OrphanVmStep
        def initialize(vm)
          @vm = vm
        end

        def perform(_)
          orphaned_vm = Models::OrphanedVm.create(
            availability_zone: @vm.instance.availability_zone,
            cid: @vm.cid,
            cloud_properties: @vm.instance.cloud_properties,
            cpi: @vm.cpi,
            stemcell_api_version: @vm.stemcell_api_version,
            orphaned_at: Time.now,
          )

          @vm.ip_addresses_dataset.all.each do |ip_address|
            ip_address.instance = nil
            ip_address.orphaned_vm = orphaned_vm
            ip_address.save
          end

          @vm.destroy
        end
      end
    end
  end
end
