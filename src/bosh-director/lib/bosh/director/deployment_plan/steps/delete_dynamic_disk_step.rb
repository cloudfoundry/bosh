module Bosh::Director
  module DeploymentPlan
    module Steps
      class DeleteDynamicDiskStep
        def initialize(disk)
          @disk = disk
          @logger = Config.logger
        end

        def perform(_report)
          return if @disk.nil?

          @logger.info("Deleting dynamic disk '#{@disk.disk_cid}'")
          cloud = Bosh::Director::CloudFactory.create.get(@disk.cpi)
          cloud.delete_disk(@disk.disk_cid) if cloud.has_disk(@disk.disk_cid)

          @disk.destroy
        end
      end
    end
  end
end
