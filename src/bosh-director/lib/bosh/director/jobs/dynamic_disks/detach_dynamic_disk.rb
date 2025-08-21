module Bosh::Director
  module Jobs::DynamicDisks
    class DetachDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers

      @queue = :normal

      def self.job_type
        :detach_dynamic_disk
      end

      def initialize(reply, disk_name)
        super()
        @reply = reply
        @disk_name = disk_name
      end

      def perform
        disk_model = Models::DynamicDisk.find(name: @disk_name)
        raise "disk `#{@disk_name}` can not be found in the database" if disk_model.nil?

        cloud = Bosh::Director::CloudFactory.create.get(disk_model.cpi)

        raise "disk `#{@disk_name}` can not be found in the cloud" unless cloud.has_disk(disk_model.disk_cid)

        vm = disk_model.vm
        unless vm.nil?
          cloud.detach_disk(disk_model.vm.cid, disk_model.disk_cid)
          disk_model.update(vm_id: nil)
        end

        nats_rpc.send_message(@reply, { 'error' => nil })
        if vm.nil?
          "disk `#{disk_model.disk_cid}` was already detached"
        else
          "detached disk `#{disk_model.disk_cid}` from vm `#{vm.cid}`"
        end
      rescue Bosh::Clouds::DiskNotAttached
        disk_model.update(vm_id: nil)
        nats_rpc.send_message(@reply, { 'error' => nil })
        "disk `#{disk_model.disk_cid}` was already detached"
      rescue => e
        nats_rpc.send_message(@reply, { 'error' => e.message })
        raise e
      end
    end
  end
end