module Bosh::Director
  # Creates VM model and call out to CPI to create VM in IaaS
  class VmCreator

    def initialize
      @cloud = Config.cloud
      @logger = Config.logger
    end

    def create(deployment, stemcell, cloud_properties, network_settings, disks=nil, env={})
      env ||= {}
      agent_id = VmCreator.generate_agent_id

      vm = Models::Vm.create(:deployment => deployment, :agent_id => agent_id)
      vm_cid = @cloud.create_vm(agent_id, stemcell.cid, cloud_properties, network_settings, disks, env)
      vm.cid = vm_cid
      vm.save
      vm
    end

    def self.generate_agent_id
      UUIDTools::UUID.random_create.to_s
    end

  end
end
