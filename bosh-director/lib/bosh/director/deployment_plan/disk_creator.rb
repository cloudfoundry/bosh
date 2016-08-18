module Bosh::Director
  module DeploymentPlan
    class DiskCreator

      def initialize(cloud, vm_cid)
        @cloud = cloud
        @vm_cid = vm_cid
      end

      def create(disk_size, cloud_properties)
        @cloud.create_disk(disk_size, cloud_properties, @vm_cid)
      end

      def attach(disk_cid)
        @cloud.attach_disk(@vm_cid, disk_cid)
      end
    end
  end
end
