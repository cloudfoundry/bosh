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
          handler_error("Disk '#{@disk_id}' is no longer in the database")
        end

        @instance = @disk.instance
        if @instance.nil?
          handler_error("Cannot find instance for disk '#{@disk.disk_cid}'")
        end
      end

      def description
        job = @instance.job || "unknown job"
        uuid = @instance.uuid || "unknown id"
        disk_label = "'#{@disk.disk_cid}' (#{job}/#{uuid}, #{@disk.size.to_i}M)"
        "Disk #{disk_label} is missing"
      end

      def instance_problem?
        false
      end

      def instance_group
        @instance.job || 'unknown job'
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
        @disk.update(active: false)
        factory = AZCloudFactory.create_with_latest_configs(@instance.deployment)
        cloud = factory.get_for_az(@instance.availability_zone, @instance.active_vm&.stemcell_api_version)

        # If VM is present we try to unmount and detach disk from VM
        if @instance.vm_cid && cloud.has_vm(@instance.vm_cid)
          agent_client = agent_client(@instance.agent_id, @instance.name)
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
            with_vm_lock(@instance.vm_cid) {  cloud.detach_disk(@instance.vm_cid, @disk.disk_cid) }
          rescue Bosh::Clouds::DiskNotAttached, Bosh::Clouds::DiskNotFound
          end
        end

        OrphanDiskManager.new(@logger).orphan_disk(@disk)

      end
    end
  end
end
