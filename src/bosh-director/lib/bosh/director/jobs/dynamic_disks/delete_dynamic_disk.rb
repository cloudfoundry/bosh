module Bosh::Director
  module Jobs::DynamicDisks
    class DeleteDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers

      @queue = :normal

      def self.job_type
        :delete_dynamic_disk
      end

      def initialize(reply, disk_name)
        super()
        @reply = reply
        @disk_name = disk_name
      end

      def perform
        disk_model = Models::DynamicDisk.find(name: @disk_name)
        unless disk_model.nil?
          cloud = Bosh::Director::CloudFactory.create.get(disk_model.cpi)
          if cloud.has_disk(disk_model.disk_cid)
            cloud.delete_disk(disk_model.disk_cid)
          end
          Models::DynamicDisk.where(id: disk_model.id).delete
        end

        response = { 'error' => nil }
        nats_rpc.send_message(@reply, response)

        if disk_model.nil?
          "disk with name `#{@disk_name}` was already deleted"
        else
          "deleted disk `#{disk_model.disk_cid}`"
        end
      rescue => e
        nats_rpc.send_message(@reply, { 'error' => e.message })
        raise e
      end
    end
  end
end