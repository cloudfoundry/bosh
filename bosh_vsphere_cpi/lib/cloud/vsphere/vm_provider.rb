module VSphereCloud
  class VMProvider
    def initialize(datacenter, client, logger)
      @datacenter = datacenter
      @client = client
      @logger = logger
    end

    def find(vm_cid)
      vm_mob = @client.find_by_inventory_path(@datacenter.vm_path(vm_cid))
      raise Bosh::Clouds::VMNotFound, "VM `#{vm_cid}' not found" if vm_mob.nil?

      Resources::VM.new(vm_cid, vm_mob, @client, @logger)
    end
  end
end
