module Bosh::Director
  module Jobs::DynamicDisks
    class DetachDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers

      @queue = :normal

      def self.job_type
        :detach_dynamic_disk
      end

      def initialize( disk_name)
        @disk_name = disk_name
      end

      def perform
        disk_model = Models::DynamicDisk.find(name: @disk_name)
        raise "disk `#{@disk_name}` can not be found in the database" if disk_model.nil?

        return "disk `#{disk_model.disk_cid}` was already detached" if disk_model.vm.nil?

        cloud = Bosh::Director::CloudFactory.create.get(disk_model.cpi, disk_model.vm.stemcell_api_version)
        vm_cid = disk_model.vm.cid

        instance_name = disk_model.vm.instance.nil? ? nil : disk_model.vm.instance.name
        agent_client = AgentClient.with_agent_id(disk_model.vm.agent_id, instance_name)
        agent_client.remove_dynamic_disk(disk_model.disk_cid)

        cloud.detach_disk(disk_model.vm.cid, disk_model.disk_cid)

        disk_model.update(vm_id: nil)

        "detached disk `#{disk_model.disk_cid}` from vm `#{vm_cid}`"
      rescue Bosh::Clouds::DiskNotAttached
        disk_model.update(vm_id: nil)
        "disk `#{disk_model.disk_cid}` was already detached"
      end
    end
  end
end