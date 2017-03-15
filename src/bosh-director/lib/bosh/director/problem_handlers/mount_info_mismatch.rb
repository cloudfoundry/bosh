# Copyright (c) 2009-2012 VMware, Inc.

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
        @vm_cid = @disk.instance.vm_cid if @disk.instance
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
        cloud = cloud_factory.for_availability_zone(@instance.availability_zone)
        cloud.attach_disk(@vm_cid, @disk_cid)
        MetadataUpdater.build.update_disk_metadata(cloud, @disk, @disk.instance.deployment.tags)
        if reboot
          reboot_vm(@instance)
        else
          agent_timeout_guard(@instance.vm_cid, @instance.credentials, @instance.agent_id) do |agent|
            agent.mount_disk(@disk_cid)
          end
        end
      end
    end
  end
end
