module Bosh::Director
  module DeploymentPlan
    class DiskCreator

      def initialize(cloud, instance_model)
        @cloud = cloud
        @vm_cid = instance_model.vm_cid
        @instance_id = instance_model.id
      end

      def create(name, disk_size, cloud_properties)
        disk_cid = @cloud.create_disk(disk_size, cloud_properties, @vm_cid)
        Models::PersistentDisk.create(
          name: name,
          disk_cid: disk_cid,
          active: false,
          instance_id: @instance_id,
          size: disk_size,
          cloud_properties: cloud_properties,
        )
      end

      def attach(disk_cid)
        @cloud.attach_disk(@vm_cid, disk_cid)
      end
    end
  end
end
