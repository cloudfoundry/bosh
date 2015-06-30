require 'common/deep_copy'

module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  class VmCreator
    include EncryptionHelper

    def self.create_for_instance(*args)
      new.create_for_instance(*args)
    end

    def self.attach_disks_for(*args)
      new.attach_disks_for(*args)
    end

    def self.create(*args)
      new.create(*args)
    end

    def initialize
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def create_for_instance(instance, disks)
      @logger.info('Creating VM')
      deployment = instance.job.deployment
      resource_pool = instance.job.resource_pool

      vm_model = create(
        deployment.model,
        resource_pool.stemcell.model,
        resource_pool.cloud_properties,
        instance.network_settings,
        disks,
        resource_pool.env,
      )

      begin
        instance.bind_to_vm_model(vm_model)
        agent_client = AgentClient.with_vm(vm_model)
        agent_client.wait_until_ready
        agent_client.update_settings(Bosh::Director::Config.trusted_certs)
        vm_model.update(:trusted_certs_sha1 => Digest::SHA1.hexdigest(Bosh::Director::Config.trusted_certs))
      rescue Exception => e
        @logger.error("Failed to create/contact VM #{vm_model.cid}: #{e.inspect}")
        VmDeleter.delete_for_instance(instance)
        raise e
      end

      attach_disks_for(instance)

      instance.apply_vm_state
    end

    def attach_disks_for(instance)
      disk_cid = instance.model.persistent_disk_cid
      return @logger.info('Skipping disk attaching') if disk_cid.nil?
      vm_model = instance.vm.model
      begin
      @cloud.attach_disk(vm_model.cid, disk_cid)
      AgentClient.with_vm(vm_model).mount_disk(disk_cid)
      rescue => e
        @logger.warn("Failed to attach disk to new VM: #{e.inspect}")
        raise e
      end
    end

    def create(deployment, stemcell, cloud_properties, network_settings,
               disks=nil, env={})
      vm = nil
      vm_cid = nil

      env = Bosh::Common::DeepCopy.copy(env)

      agent_id = self.class.generate_agent_id

      options = {
          :deployment => deployment,
          :agent_id => agent_id,
          :env => env
      }

      if Config.encryption?
        credentials = generate_agent_credentials
        env['bosh'] ||= {}
        env['bosh']['credentials'] = credentials
        options[:credentials] = credentials
      end

      count = 0
      begin
        vm_cid = @cloud.create_vm(agent_id, stemcell.cid, cloud_properties, network_settings, disks, env)
      rescue Bosh::Clouds::VMCreationFailed => e
        count += 1
        logger.error("failed to create VM, retrying (#{count})")
        retry if e.ok_to_retry && count < Config.max_vm_create_tries
        raise e
      end

      options[:cid] = vm_cid
      vm = Models::Vm.new(options)

      vm.save
      VmMetadataUpdater.build.update(vm, {})
      vm
    rescue => e
      logger.error("error creating vm: #{e.message}")
      delete_vm(vm_cid) if vm_cid
      vm.destroy if vm
      raise e
    end

    def delete_vm(vm_cid)
      @cloud.delete_vm(vm_cid)
    rescue => e
      logger.error("error cleaning up #{vm_cid}: #{e.message}\n#{e.backtrace.join("\n")}")
    end

    def self.generate_agent_id
      SecureRandom.uuid
    end

    def logger
      Config.logger
    end

    private



    class DiskAttacher
      def initialize(instance, vm_model, agent_client, cloud, logger)
        @instance = instance
        @vm_model = vm_model
        @agent_client = agent_client
        @cloud = cloud
        @logger = logger
      end


    end
  end
end
