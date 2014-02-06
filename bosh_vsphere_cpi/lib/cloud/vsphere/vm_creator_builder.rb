require 'cloud/vsphere/vm_creator'

module VSphereCloud
  class VmCreatorBuilder
    def build(resources, cloud_properties, client, logger, cpi)
      VmCreator.new(
        cloud_properties.fetch('ram'),
        cloud_properties.fetch('disk'),
        cloud_properties.fetch('cpu'),
        resources,
        client,
        logger,
        cpi,
      )
    end
  end
end
