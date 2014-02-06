require 'cloud/vsphere/vm_creator'

module VSphereCloud
  class VmCreatorBuilder
    def build(resources, client, logger, cpi)
      VmCreator.new(resources, client, logger, cpi)
    end
  end
end
