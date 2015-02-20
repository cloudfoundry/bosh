module VSphereCloud
  class VMProvider
    def initialize(resources, client, logger)
      @resources = resources
      @client = client
      @logger = logger
    end

    def find(vm_cid)
      @resources.datacenters.each_value do |datacenter|
        vm_mob = @client.find_by_inventory_path([datacenter.name, 'vm', datacenter.vm_folder.path_components, vm_cid])
        return Resources::VM.new(vm_cid, vm_mob, @client, @logger)
      end
      raise Bosh::Clouds::VMNotFound, "VM `#{vm_cid}' not found"
    end
  end
end
