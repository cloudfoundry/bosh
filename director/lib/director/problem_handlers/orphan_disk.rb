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
        handler_error("Disk #{@disk_id} is not mounted") if disk_vm.nil?
        # Currently the director allows ONLY-ONE persistent disk per
        # instance. We are about to activate a disk but the instance already
        # has an active disk.
        # For now let's be conservative and return an error.
        instance = @disk.instance
        unless instance.persistent_disk.nil?
          handler_error("Instance #{instance.id} already has an active disk #{instance.persistent_disk}")
        end
        @disk.active = true
        @disk.save
        true
      end

      def delete_disk
        vm = disk_vm
        handler_error("Disk #{@disk_id} is currently in use (vmid = #{vm.cid})") unless vm.nil?
        cloud  = Config.cloud

        disk_cid = @disk.disk_cid
        if vm
          cloud.detach_disk(vm.cid, disk_cid) rescue nil
        end
        cloud.delete_disk(disk_cid) rescue nil
        @disk.destroy
        true
      end

      # return the owner(vm) of the disk
      def disk_vm
        instance = @disk.instance
        return nil if instance.nil?

        vm = instance.vm
        return nil if vm.nil?

        agent = AgentClient.new(vm.agent_id)
        begin
          disk_list = agent.list_disk
        rescue RuntimeError
          # old stemcells without 'list_disk' support. We need to play
          # conservative and assume that the disk is mounted.
          return vm
        end
        disk_cid = @disk.disk_cid
        return nil if disk_list.find { |d_cid| d_cid == disk_cid }.nil?
        vm
      end
    end
  end
end
