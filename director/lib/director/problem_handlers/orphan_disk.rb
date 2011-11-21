module Bosh::Director
  module ProblemHandlers
    class OrphanDisk < Base

      register_as :orphan_disk
      auto_resolution :report

      def initialize(disk_id, data)
        super
        @disk_id = disk_id
        @data = data
        @disk = Models::PersistentDisk[@disk_id]
        @cloud  = Config.cloud

        if @disk.nil?
          handler_error("Disk `#{@disk_id}' is no longer in the database")
        end
      end

      def problem_still_exists?
        @disk = Models::PersistentDisk[@disk_id]
        return false if @disk.nil?
        !@disk.active
      end

      def description
        "Disk #{@disk_id} is in in-active state"
      end

      resolution :report do
        plan { "Report problem" }
        action { report }
      end

      resolution :delete_disk do
        plan { "Delete disk #{@disk_id}" }
        action { delete_disk }
      end

      resolution :activate_disk do
        plan { "Activate disk #{@disk_id}" }
        action { activate_disk }
      end

      def report
        # TODO
        true
      end

      def activate_disk
        handler_error("Disk #{@disk_id} is not mounted") unless disk_mounted?
        @disk.active = true
        @disk.save
        true
      end

      def delete_disk
        handler_error("Disk #{@disk_id} is currently in use by vm #{vm.id}") if disk_mounted?

        disk_cid = @disk.disk_cid
        vm_cid = get_disk_vm.cid
        @cloud.detach_disk(vm_cid, disk_cid) rescue nil
        @cloud.delete_disk(disk_cid) rescue nil
        @disk.destroy
        true
      end

      # return the VM associated with the disk
      def get_disk_vm
        vm = nil
        instance = @disk.instance
        vm = instance.vm unless instance.nil?
        vm
      end

      # ping the agent to see if the disk in question is being used (mounted)
      def disk_mounted?
        vm = get_disk_vm
        return false if vm.nil?
        agent = AgentClient.new(vm.agent_id)
        disk_list = agent.list_disk
        disk_cid = @disk.disk_cid
        !disk_list.find { |disk_cid| disk_cid == disk_cid}.nil?
      end
    end
  end
end
