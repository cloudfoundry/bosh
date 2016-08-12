module Bosh::Director
  class InstanceModelHelper
    def self.prepare_instance_spec_for_saving!(instance_spec)
      modified_spec = Bosh::Common::DeepCopy.copy(instance_spec)
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      self.adjust_spec_env_on_save!(modified_spec, config_server_enabled)

      modified_spec
    end

    def self.adjust_instance_spec_after_retrieval!(instance_spec)
      modified_spec = Bosh::Common::DeepCopy.copy(instance_spec)
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      self.adjust_spec_env_on_retrieval!(modified_spec, config_server_enabled)

      modified_spec
    end

    private

    def self.adjust_spec_env_on_save!(instance_spec, config_server_enabled)
      if config_server_enabled
        instance_spec['env'] = instance_spec['uninterpolated_env']
      end

      instance_spec.delete('uninterpolated_env')
    end

    def self.adjust_spec_env_on_retrieval!(instance_spec, config_server_enabled)
      instance_spec['uninterpolated_env'] = Bosh::Common::DeepCopy.copy(instance_spec['env'])
      if config_server_enabled
        instance_spec['env'] = Bosh::Director::ConfigServer::ConfigParser.parse(instance_spec['env'])
      end
    end

  end
end
