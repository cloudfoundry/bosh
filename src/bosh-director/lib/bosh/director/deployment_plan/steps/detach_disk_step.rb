module Bosh::Director
  module DeploymentPlan
    module Steps
      class DetachDiskStep
        def initialize(disk)
          @disk = disk
          @logger = Config.logger
        end

        def perform(_report)
          return if @disk.nil?

          cloud_factory = CloudFactory.create_with_latest_configs
          cloud = cloud_factory.get(@disk.cpi)
          @logger.info("Detaching disk #{@disk.disk_cid}")
          cloud.detach_disk(@disk.instance.vm_cid, @disk.disk_cid)
        rescue Bosh::Clouds::DiskNotAttached
          if @disk.active
            raise CloudDiskNotAttached,
                  "'#{@disk.instance}' VM should have persistent disk " \
                  "'#{@disk.disk_cid}' attached but it doesn't (according to CPI)"
          end
        end
      end
    end
  end
end
