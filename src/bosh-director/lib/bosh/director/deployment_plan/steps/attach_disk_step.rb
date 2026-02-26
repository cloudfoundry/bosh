module Bosh::Director
  module DeploymentPlan
    module Steps
      class AttachDiskStep
        include LockHelper

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
          disk_hint = with_vm_lock(@disk.instance.vm_cid) { attach_disk_cloud.attach_disk(@disk.instance.vm_cid, @disk.disk_cid) }

          if disk_hint
            agent_client(@disk.instance).wait_until_ready
            agent_client(@disk.instance).add_persistent_disk(@disk.disk_cid, disk_hint)
          end

          metadata_updater_cloud = cloud_factory.get(@disk.cpi)
          MetadataUpdater.build.update_disk_metadata(metadata_updater_cloud, @disk, @tags)
        end

        def agent_client(instance_model)
          @agent_client ||= AgentClient.with_agent_id(instance_model.agent_id, instance_model.name)
        end
      end
    end
  end
end
