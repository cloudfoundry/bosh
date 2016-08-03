module Bosh::Director
  class InstanceModelHelper
    def self.prepare_instance_spec_for_saving!(instance_spec)
      modified_spec = Bosh::Common::DeepCopy.copy(instance_spec)

      if Bosh::Director::Config.config_server_enabled
        modified_spec['properties'] = modified_spec['uninterpolated_properties']
      end

      modified_spec.delete('uninterpolated_properties')

      modified_spec
    end

    def self.adjust_instance_spec_after_retrieval!(instance_spec)
      instance_spec['uninterpolated_properties'] = Bosh::Common::DeepCopy.copy(instance_spec['properties'])
      if Bosh::Director::Config.config_server_enabled
        instance_spec['properties'] = Bosh::Director::ConfigServer::ConfigParser.parse(instance_spec['properties'])
      end

      instance_spec
    end
  end
end
