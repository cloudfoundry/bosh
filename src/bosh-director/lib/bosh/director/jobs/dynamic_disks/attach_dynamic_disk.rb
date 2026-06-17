module Bosh::Director
  module Jobs::DynamicDisks
    class AttachDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers
      include LockHelper

      @queue = :dynamic_disks

      def self.job_type
        :attach_dynamic_disk
      end

      def initialize(disk_name, instance_id)
        @disk_name = disk_name
        @instance_id = instance_id
      end

      def perform
        disk_model = Models::DynamicDisk.find(name: @disk_name)
        raise "disk `#{@disk_name}` not found" if disk_model.nil?

        instance = Models::Instance.find(uuid: @instance_id)
        raise "instance `#{@instance_id}` not found" if instance.nil?

        vm = instance.active_vm
        raise "no active vm found for instance `#{@instance_id}`" if vm.nil?

        unless disk_model.vm.nil?
          return "disk `#{@disk_name}` is already attached to vm `#{disk_model.vm.cid}`" if disk_model.vm.id == vm.id

          raise "disk `#{@disk_name}` is already attached to a different vm `#{disk_model.vm.cid}`"
        end

        cloud = Bosh::Director::CloudFactory.create.get(disk_model.cpi, vm.stemcell_api_version)
        disk_hint = with_vm_lock(vm.cid, timeout: VM_LOCK_TIMEOUT) { cloud.attach_disk(vm.cid, disk_model.disk_cid) }
        disk_model.update(vm_id: vm.id, availability_zone: vm.instance.availability_zone, disk_hint: disk_hint)

        agent_client = AgentClient.with_agent_id(vm.agent_id, instance.name)
        agent_client.add_dynamic_disk(disk_model.disk_cid, disk_model.disk_hint)

        "attached disk `#{@disk_name}` to vm `#{vm.cid}` in deployment `#{instance.deployment.name}`"
      end
    end
  end
end
