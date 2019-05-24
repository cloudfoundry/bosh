module Bosh::Director
  module ProblemHandlers
    class MountInfoMismatch < Base

      register_as :mount_info_mismatch
      auto_resolution :ignore

      def initialize(disk_id, data)
        @disk = Models::PersistentDisk[disk_id]
        @data = data

        if @disk.nil?
          handler_error("Disk '#{disk_id}' is no longer in the database")
        end

        @disk_cid = @disk.disk_cid

        active_vm = @disk.instance&.active_vm
        unless active_vm.nil?
          @vm_cid = active_vm.cid
          @vm_stemcell_api_version = active_vm.stemcell_api_version
        end

        handler_error("Can't find corresponding vm-cid for disk '#{@disk_cid}'") if @vm_cid.nil?

        @instance = @disk.instance

        @disk_owners = @data['owner_vms']
      end

      def description
        out =  "Inconsistent mount information:\n"
        out += "Record shows that disk '#{@disk_cid}' should be mounted on #{@vm_cid}.\n"
        out += "However it is currently :\n"

        if @disk_owners.size == 0
          out += "\tNot mounted in any VM"
        else
          out += "\tMounted on: #{@disk_owners.join(", ")}"
        end
        out
      end

      def instance_problem?
        false
      end

      resolution :ignore do
        plan { "Ignore" }
        action { }
      end

      resolution :reattach_disk do
        plan { "Reattach disk to instance" }
        action { reattach_disk(false) }
      end

      resolution :reattach_disk_and_reboot do
        plan { "Reattach disk and reboot instance" }
        action { reattach_disk(true) }
      end

      def reattach_disk(reboot = false)
        az_cloud_factory = AZCloudFactory.create_with_latest_configs(@instance.deployment)
        cloud_for_attach_disk = az_cloud_factory.get_for_az(@instance.availability_zone, @vm_stemcell_api_version)
        disk_hint = cloud_for_attach_disk.attach_disk(@vm_cid, @disk_cid)

        cloud_for_update_metadata = az_cloud_factory.get_for_az(@instance.availability_zone)
        MetadataUpdater.build.update_disk_metadata(cloud_for_update_metadata, @disk, @disk.instance.deployment.tags)
        send_disk_hint_to_agent(disk_hint) if disk_hint

        agent_timeout_guard(@instance.vm_cid, @instance.agent_id, @instance.name) do |agent|
          agent.mount_disk(@disk_cid)
        end

        reboot_vm(@instance) if reboot
      end

      private

      def send_disk_hint_to_agent(disk_hint)
        agent_timeout_guard(@instance.vm_cid, @instance.agent_id, @instance.name) do |agent|
          agent.add_persistent_disk(@disk_cid, disk_hint)
        end
      end
    end
  end
end
