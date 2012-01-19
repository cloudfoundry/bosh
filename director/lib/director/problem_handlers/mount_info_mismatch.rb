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
        @vm_cid = @disk.instance.vm.cid
        @disk_cid = @disk.disk_cid
        @disk_owners = @data['owner_vms']
      end

      def description
        out =  "Inconsistent mount information:\n"
        out += "Record shows that disk #{@disk_cid}' should be mounted on #{@vm_cid}.\n"
        out += "However it is currently :\n"

        if @disk_owners.size == 0
          out += "\tNOT mounted in any VM"
        else
          out += "\tMounted on : #{@disk_owners.join(", ")}"
        end
        out
      end

      resolution :ignore do
        plan { "Ignore - Cannot be fixed using cloudcheck." }
        action { }
      end
    end
  end
end
