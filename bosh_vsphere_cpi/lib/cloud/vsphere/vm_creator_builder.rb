require 'cloud/vsphere/vm_creator'

module VSphereCloud
  class VmCreatorBuilder
    def build(resources, cloud_properties, client, cloud_searcher, logger, cpi, agent_env, file_provider, disk_provider)
      VmCreator.new(
        cloud_properties.fetch('ram'),
        cloud_properties.fetch('disk'),
        cloud_properties.fetch('cpu'),
        cloud_properties.fetch('nested_hardware_virtualization', false),
        resources,
        client,
        cloud_searcher,
        logger,
        cpi,
        agent_env,
        file_provider,
        disk_provider
      )
    end
  end
end
