module Bosh::Director
  class InstanceUpdater::VmUpdater
    def initialize(instance, vm_model, agent_client, job_renderer, cloud, max_update_tries, logger)
      @instance = instance
      @vm_model = vm_model
      @agent_client = agent_client
      @job_renderer = job_renderer
      @cloud = cloud
      @max_update_tries = max_update_tries
      @logger = logger
    end

    def update(new_disk_cid)
      if !@instance.resource_pool_changed? && !new_disk_cid
        @logger.info('Skipping VM update')
        return [@vm_model, @agent_client]
      end

      disk_detacher = DiskDetacher.new(@instance, @vm_model, @agent_client, @cloud, @logger)
      disk_detacher.detach

      @max_update_tries.times do |try|
        vm_deleter = VmDeleter.new(@instance, @vm_model, @cloud, @logger)
        vm_deleter.delete

        vm_creator = VmCreator.new(@instance, @cloud, @logger)
        @vm_model, @agent_client = vm_creator.create(new_disk_cid)

        begin
          disk_attacher = DiskAttacher.new(@instance, @vm_model, @agent_client, @cloud, @logger)
          disk_attacher.attach
          break
        rescue Bosh::Clouds::NoDiskSpace => e
          if e.ok_to_retry && try < @max_update_tries-1
            @logger.warn("Retrying attach disk operation #{try}: #{e.inspect}")
          else
            @logger.warn("Failed to attach disk to new VM: #{e.inspect}")
            raise CloudNotEnoughDiskSpace,
                  "Not enough disk space to update `#{@instance}'"
          end
        end
      end

      @instance.apply_vm_state
      @job_renderer.render_job_instance(@instance)

      [@vm_model, @agent_client]
    end

    def detach
      @logger.info('Detaching VM')

      disk_detacher = DiskDetacher.new(@instance, @vm_model, @agent_client, @cloud, @logger)
      disk_detacher.detach

      vm_deleter = VmDeleter.new(@instance, @vm_model, @cloud, @logger)
      vm_deleter.delete

      @instance.job.resource_pool.add_idle_vm
    end

    def attach_missing_disk
      if !@instance.model.persistent_disk_cid || @instance.disk_currently_attached?
        @logger.info('Skipping attaching missing VM')
        return
      end

      begin
        disk_attacher = DiskAttacher.new(@instance, @vm_model, @agent_client, @cloud, @logger)
        disk_attacher.attach
      rescue Bosh::Clouds::NoDiskSpace => e
        @logger.warn("Failed attaching missing disk first time: #{e.inspect}")
        update(@instance.model.persistent_disk_cid)
      end
    end

    private

    class VmCreator
      def initialize(instance, cloud, logger)
        @instance = instance
        @cloud = cloud
        @logger = logger
      end

      def create(new_disk_id)
        @logger.info('Creating VM')
        vm_model = new_vm_model(new_disk_id)

        begin
          @instance.bind_to_vm_model(vm_model)

          agent_client = AgentClient.with_defaults(vm_model.agent_id)
          agent_client.wait_until_ready
          agent_client.update_settings(Bosh::Director::Config.trusted_certs)
          vm_model.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs))
        rescue Exception => e
          @logger.error("Failed to create/contact VM #{vm_model.cid}: #{e.inspect}")
          VmDeleter.new(@instance, vm_model, @cloud, @logger).delete
          raise e
        end

        [vm_model, agent_client]
      end

      def new_vm_model(new_disk_id)
        deployment = @instance.job.deployment
        resource_pool = @instance.job.resource_pool

        Bosh::Director::VmCreator.create(
          deployment.model,
          resource_pool.stemcell.model,
          resource_pool.cloud_properties,
          @instance.network_settings,
          [@instance.model.persistent_disk_cid, new_disk_id].compact,
          resource_pool.env,
        )
      end
    end

    class VmDeleter
      def initialize(instance, vm_model, cloud, logger)
        @instance = instance
        @vm_model = vm_model
        @cloud = cloud
        @logger = logger
      end

      def delete
        @logger.info('Deleting VM')

        @cloud.delete_vm(@vm_model.cid)

        @instance.model.db.transaction do
          @instance.model.vm = nil
          @instance.model.save

          @vm_model.destroy
        end
      end
    end

    class DiskAttacher
      def initialize(instance, vm_model, agent_client, cloud, logger)
        @instance = instance
        @vm_model = vm_model
        @agent_client = agent_client
        @cloud = cloud
        @logger = logger
      end

      def attach
        if @instance.model.persistent_disk_cid.nil?
          @logger.info('Skipping disk attaching')
          return
        end

        @cloud.attach_disk(@vm_model.cid, @instance.model.persistent_disk_cid)

        @agent_client.mount_disk(@instance.model.persistent_disk_cid)
      end
    end

    class DiskDetacher
      def initialize(instance, vm_model, agent_client, cloud, logger)
        @instance = instance
        @vm_model = vm_model
        @agent_client = agent_client
        @cloud = cloud
        @logger = logger
      end

      def detach
        disk_list = @agent_client.list_disk
        if disk_list.empty?
          @logger.info('Skipping disk detaching')
          return
        end

        if @instance.model.persistent_disk_cid.nil?
          raise AgentUnexpectedDisk,
                "`#{@instance}' VM has disk attached but it's not reflected in director DB"
        end

        @agent_client.unmount_disk(@instance.model.persistent_disk_cid)

        @cloud.detach_disk(@vm_model.cid, @instance.model.persistent_disk_cid)
      end
    end
  end
end
