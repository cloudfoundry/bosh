module Bosh::Director
  module Jobs::DynamicDisks
    class ProvideDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers
      include LockHelper

      @queue = :normal

      def self.job_type
        :provide_dynamic_disk
      end

      def initialize(instance_id, disk_name, disk_pool_name, disk_size, metadata)
        @instance_id = instance_id
        @disk_name = disk_name
        @disk_pool_name = disk_pool_name
        @disk_size = disk_size
        @metadata = metadata
      end

      def perform
        instance = Models::Instance.find(uuid: @instance_id)
        raise "instance `#{@instance_id}` not found" if instance.nil?

        vm = instance.active_vm
        raise "no active vm found for instance `#{@instance_id}`" if vm.nil?

        cloud_properties = find_disk_cloud_properties(instance, @disk_pool_name)
        cloud = Bosh::Director::CloudFactory.create.get(vm.cpi)

        disk_model = Models::DynamicDisk.find(name: @disk_name)
        if disk_model.nil?
          cloud_properties['name'] = @disk_name
          disk_cid = cloud.create_disk(@disk_size, cloud_properties, vm.cid)
          disk_model = Models::DynamicDisk.create(
            name: @disk_name,
            disk_cid: disk_cid,
            deployment_id: instance.deployment.id,
            size: @disk_size,
            disk_pool_name: @disk_pool_name,
            cpi: vm.cpi,
          )
        end

        if disk_model.vm.nil?
          disk_hint = with_vm_lock(vm.cid, timeout: VM_LOCK_TIMEOUT) { cloud.attach_disk(vm.cid, disk_model.disk_cid) }
          disk_model.update(vm_id: vm.id, availability_zone: vm.instance.availability_zone, disk_hint: disk_hint)
        else
          if disk_model.vm.id != vm.id
            raise "disk is attached to a different vm `#{disk_model.vm.cid}`"
          end
        end

        if !@metadata.nil? && disk_model.metadata != @metadata
          MetadataUpdater.build.update_dynamic_disk_metadata(cloud, disk_model, @metadata)
          disk_model.update(metadata: @metadata)
        end

        unless disk_model.disk_hint.nil?
          agent_client = AgentClient.with_agent_id(vm.agent_id, instance.name)
          agent_client.add_dynamic_disk(disk_model.disk_cid, disk_model.disk_hint)
        end

        disk_info = { "disk_cid": disk_model.disk_cid }

        task_result.write(JSON.generate(disk_info))
        task_result.write("\n")

        "attached disk `#{@disk_name}` to `#{vm.cid}` in deployment `#{vm.instance.deployment.name}`"
      end
    end
  end
end