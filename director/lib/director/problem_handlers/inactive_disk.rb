module Bosh::Director
  module ProblemHandlers
    class InactiveDisk < Base

      register_as :inactive_disk
      auto_resolution :ignore

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
        "Disk #{@disk_id} is inactive"
      end

      resolution :ignore do
        plan { "Ignore problem" }
        action { }
      end

      resolution :delete_disk do
        plan { "Delete disk #{@disk_id}" }
        action { delete_disk }
      end

      resolution :activate_disk do
        plan { "Activate disk #{@disk_id}" }
        action { activate_disk }
      end

      def activate_disk
        handler_error("Disk #{@disk_id} is not mounted") unless disk_mounted?
        # Currently the director allows ONLY one persistent disk per
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
        handler_error("Disk #{@disk_id} is currently in use") if disk_mounted?

        cloud = Config.cloud
        disk_cid = @disk.disk_cid
        vm = disk_vm
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
        instance.vm
      end

      # check to see if the disk is mounted
      def disk_mounted?
        vm = disk_vm
        return false if vm.nil?
        agent = AgentClient.new(vm.agent_id)
        begin
          disk_list = agent.list_disk
        rescue RuntimeError
          # old stemcells without 'list_disk' support. We need to play
          # conservative and assume that the disk is mounted.
          return true
        end
        disk_cid = @disk.disk_cid
        !disk_list.find { |d_cid| d_cid == disk_cid }.nil?
      end
    end
  end
end
