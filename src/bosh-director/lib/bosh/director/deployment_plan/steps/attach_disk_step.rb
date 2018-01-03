module Bosh::Director
  module DeploymentPlan
    module Steps
      class AttachDiskStep
        def initialize(disk, tags)
          @disk = disk
          @logger = Config.logger
          @tags = tags
        end

        def perform(_report)
          return if @disk.nil?

          cloud_factory = CloudFactory.create_with_latest_configs
          cloud = cloud_factory.get(@disk.cpi)
          @logger.info("Attaching disk #{@disk.disk_cid}")
          cloud.attach_disk(@disk.instance.vm_cid, @disk.disk_cid)
          MetadataUpdater.build.update_disk_metadata(cloud, @disk, @tags)
        end
      end
    end
  end
end
