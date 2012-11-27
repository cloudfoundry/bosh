module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  # @todo refactor to accept Instance or IdleVM instead of passing in all of the
  # arguments directly.
  class VmCreator
    include EncryptionHelper
    include MetadataHelper

    def self.create(*args)
      new.create(*args)
    end

    def initialize
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def create(deployment, stemcell, cloud_properties, network_settings,
               disks=nil, env={})
      env ||= {}
      env.extend(DeepCopy)
      env = env._deep_copy

      agent_id = self.class.generate_agent_id

      if Config.encryption?
        credentials = generate_agent_credentials
        env["bosh"] ||= {}
        env["bosh"]["credentials"] = credentials
      end

      vm = Models::Vm.create(:deployment => deployment, :agent_id => agent_id)
      vm_cid = @cloud.create_vm(agent_id, stemcell.cid, cloud_properties,
                                network_settings, disks, env)
      vm.cid = vm_cid
      vm.env = env

      if Config.encryption?
        vm.credentials = credentials
      end

      vm.save
      update_vm_metadata(vm)
      vm
    end

    def self.generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end
end
