require 'common/deep_copy'

module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  class VmCreator
    include EncryptionHelper

    def self.create(*args)
      new.create(*args)
    end

    def initialize
      @cloud = Config.cloud
      @logger = Config.logger
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

  end
end
