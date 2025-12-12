module Bosh::Director
  module Jobs::DynamicDisks
    class DeleteDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers

      @queue = :dynamic_disks

      def self.job_type
        :delete_dynamic_disk
      end

      def initialize(disk_name)
        @disk_name = disk_name
      end

      def perform
        disk_model = Models::DynamicDisk.find(name: @disk_name)
        return "disk with name `#{@disk_name}` was already deleted" if disk_model.nil?

        cloud = Bosh::Director::CloudFactory.create.get(disk_model.cpi)
        disk_cid = disk_model.disk_cid

        cloud.delete_disk(disk_cid) if cloud.has_disk(disk_cid)
        disk_model.destroy

        "deleted disk `#{disk_cid}`"
      end
    end
  end
end