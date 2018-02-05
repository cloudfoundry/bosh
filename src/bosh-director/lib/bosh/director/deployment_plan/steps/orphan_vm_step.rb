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
            instance_id: @vm.instance_id,
            orphaned_at: Time.now,
          )

          @vm.ip_addresses_dataset.all.each do |ip_address|
            orphaned_vm.add_ip_address(ip_address)
          end
          @vm.remove_all_ip_addresses
          @vm.delete
        end
      end
    end
  end
end
