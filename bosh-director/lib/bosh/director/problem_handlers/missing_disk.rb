module Bosh::Director
  module ProblemHandlers
    class MissingDisk < Base

      register_as :missing_disk
      auto_resolution :ignore

      def initialize(disk_id, data)
        super
        @disk_id = disk_id
        @data = data
        @disk = Models::PersistentDisk[@disk_id]

        if @disk.nil?
          handler_error("Disk `#{@disk_id}' is no longer in the database")
        end

        @instance = @disk.instance
        if @instance.nil?
          handler_error("Cannot find instance for disk `#{@disk.disk_cid}'")
        end

        @vm = @instance.vm
      end

      def description
        job = @instance.job || "unknown job"
        index = @instance.index || "unknown index"
        disk_label = "`#{@disk.disk_cid}' (#{job}/#{index}, #{@disk.size.to_i}M)"
        "Disk #{disk_label} is missing"
      end

      resolution :ignore do
        plan { 'Skip for now' }
        action { }
      end

      resolution :delete_disk_reference do
        plan { 'Delete disk reference (DANGEROUS!)' }
        action { delete_disk_reference }
      end

      def delete_disk_reference
        @disk.db.transaction do
          @disk.update(active: false)
        end

        # If VM is present we try to unmount and detach disk from VM
        if @vm && @vm.cid && cloud.has_vm?(@vm.cid)
          agent_client = agent_client(@vm)
          disk_list = []

          begin
            disk_list = agent_client.list_disk
            if disk_list.include?(@disk.disk_cid)
              @logger.debug('Trying to unmount disk')
              agent_client.unmount_disk(@disk.disk_cid)
            end

          rescue Bosh::Director::RpcTimeout
            # When agent is not responding it probably is failing to
            # access missing disk. We continue with sending detach_disk
            # which should update agent settings.json and it should be
            # restarted successfully.
            @logger.debug('Agent is not responding, skipping unmount')
          rescue Bosh::Director::RpcRemoteException => e
            handler_error("Cannot unmount disk, #{e.message}")
          end

          begin
            @logger.debug('Sending cpi request: detach_disk')
            cloud.detach_disk(@vm.cid, @disk.disk_cid) if @vm.cid
          rescue Bosh::Clouds::DiskNotAttached
          end
        end

        @logger.debug('Deleting disk snapshots')
        Api::SnapshotManager.delete_snapshots(@disk.snapshots)

        begin
          @logger.debug('Sending cpi request: delete_disk')
          cloud.delete_disk(@disk.disk_cid)
        rescue Bosh::Clouds::DiskNotFound
        end

        @logger.debug('Removing disk reference from database')
        @disk.destroy
      end
    end
  end
end
