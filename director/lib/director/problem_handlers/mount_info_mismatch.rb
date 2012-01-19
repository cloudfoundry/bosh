module Bosh::Director
  module ProblemHandlers
    class MountInfoMismatch < Base

      register_as :mount_info_mismatch
      auto_resolution :ignore

      def initialize(disk_id, data)
        @disk = Models::PersistentDisk[disk_id]
        @data = data

        if @disk.nil?
          handler_error("Disk `#{disk_id}' is no longer in the database")
        end

        @disk_cid = @disk.disk_cid
        @vm_cid = @disk.instance.vm.cid if @disk.instance && @disk.instance.vm
        handler_error("Can't find corresponding vm-cid for disk #{@disk_cid}") if @vm_cid.nil?

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
        plan { "Ignore - Cannot be fixed using cloudcheck" }
        action { }
      end
    end
  end
end
