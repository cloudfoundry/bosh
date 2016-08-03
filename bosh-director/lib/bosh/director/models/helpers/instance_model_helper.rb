module Bosh::Director
  class InstanceModelHelper
    def self.prepare_instance_spec_for_saving!(instance_spec)
      modified_spec = Bosh::Common::DeepCopy.copy(instance_spec)
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      self.adjust_spec_properties_on_save!(modified_spec, config_server_enabled)
      self.adjust_links_properties_on_save!(modified_spec, config_server_enabled)

      modified_spec
    end

    def self.adjust_instance_spec_after_retrieval!(instance_spec)
      modified_spec = Bosh::Common::DeepCopy.copy(instance_spec)
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      self.adjust_spec_properties_on_retrieval!(modified_spec, config_server_enabled)
      self.adjust_links_properties_on_retrieval!(modified_spec, config_server_enabled)

      modified_spec
    end

    private

    def self.adjust_spec_properties_on_save!(instance_spec, config_server_enabled)
      if config_server_enabled
        instance_spec['properties'] = instance_spec['uninterpolated_properties']
      end

      instance_spec.delete('uninterpolated_properties')
    end

    def self.adjust_spec_properties_on_retrieval!(instance_spec, config_server_enabled)
      instance_spec['uninterpolated_properties'] = Bosh::Common::DeepCopy.copy(instance_spec['properties'])
      if config_server_enabled
        instance_spec['properties'] = Bosh::Director::ConfigServer::ConfigParser.parse(instance_spec['properties'])
      end
    end

    def self.adjust_links_properties_on_save!(instance_spec, config_server_enabled)
      return if instance_spec['links'].nil?

      instance_spec['links'].each do |link_name, link_spec|
        if config_server_enabled
          link_spec['properties'] = link_spec['uninterpolated_properties']
        end
        link_spec.delete('uninterpolated_properties')
      end
    end

    def self.adjust_links_properties_on_retrieval!(instance_spec, config_server_enabled)
      return if instance_spec['links'].nil?

      instance_spec['links'].each do |link_name, link_spec|
        link_spec['uninterpolated_properties'] = Bosh::Common::DeepCopy.copy(link_spec['properties'])
        if config_server_enabled
          link_spec['properties'] = Bosh::Director::ConfigServer::ConfigParser.parse(link_spec['properties'])
        end
      end
    end

  end
end
