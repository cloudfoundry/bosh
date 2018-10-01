module Bosh::Director
  module DeploymentPlan
    module Steps
      class AttachDiskStep
        def initialize(disk, tags)
          @disk = disk
          @logger = Config.logger
          @tags = tags
        end

        def perform(report)
          return if @disk.nil?

          instance_active_vm = @disk.instance.active_vm
          return if instance_active_vm.nil?

          cloud_factory = CloudFactory.create
          attach_disk_cloud = cloud_factory.get(@disk.cpi, instance_active_vm.stemcell_api_version)
          @logger.info("Attaching disk #{@disk.disk_cid}")
          report.disk_hint = attach_disk_cloud.attach_disk(@disk.instance.vm_cid, @disk.disk_cid)

          agent_client(@disk.instance).wait_until_ready
          agent_client(@disk.instance).update_persistent_disk(@disk.disk_cid, report.disk_hint)

          metadata_updater_cloud = cloud_factory.get(@disk.cpi)
          MetadataUpdater.build.update_disk_metadata(metadata_updater_cloud, @disk, @tags)
        end

        def agent_client(instance_model)
          @agent_client ||= AgentClient.with_agent_id(instance_model.agent_id)
        end
      end
    end
  end
end
