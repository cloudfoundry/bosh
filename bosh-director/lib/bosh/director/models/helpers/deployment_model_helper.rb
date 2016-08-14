module Bosh::Director
  class DeploymentModelHelper
    def self.prepare_deployment_links_spec_for_saving(deployment_links_spec)
      modified_spec = Bosh::Common::DeepCopy.copy(deployment_links_spec)
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      self.modify_links_spec_for_saving!(modified_spec, config_server_enabled)

      modified_spec
    end

    def self.adjust_deployment_links_spec_after_retrieval(deployment_links_spec)
      modified_spec = Bosh::Common::DeepCopy.copy(deployment_links_spec)
      config_server_enabled = Bosh::Director::Config.config_server_enabled

      self.modify_links_spec_on_retrieval!(modified_spec, config_server_enabled)

      modified_spec
    end

    private

    # Check the test of this class to see a sample of deployment_links_spec
    def self.modify_links_spec_for_saving!(deployment_links_spec, config_server_enabled)
      deployment_links_spec.each do |instance_group_name, instance_group_value|
        instance_group_value.each do | job_name, job_value|
          job_value.each do |link_name, link_value|
            link_value.each do |link_type_name, link_spec|
              self.modify_links_properties_on_save!(link_spec, config_server_enabled)
            end
          end
        end
      end
    end

    def self.modify_links_properties_on_save!(link_spec, config_server_enabled)
      return if link_spec.nil?

      if config_server_enabled
        link_spec['properties'] = Bosh::Common::DeepCopy.copy(link_spec['uninterpolated_properties'])
      end
      link_spec.delete('uninterpolated_properties')
    end

    # Check the test of this class to see a sample of deployment_links_spec
    def self.modify_links_spec_on_retrieval!(deployment_links_spec, config_server_enabled)
      deployment_links_spec.each do |instance_group_name, instance_group_value|
        instance_group_value.each do | job_name, job_value|
          job_value.each do |link_name, link_value|
            link_value.each do |link_type_name, link_spec|
              self.modify_links_properties_on_retrieval!(link_spec, config_server_enabled)
            end
          end
        end
      end
    end

    def self.modify_links_properties_on_retrieval!(link_spec, config_server_enabled)
      return if link_spec.nil?

      link_spec['uninterpolated_properties'] = Bosh::Common::DeepCopy.copy(link_spec['properties'])
      if config_server_enabled
        link_spec['properties'] = Bosh::Director::ConfigServer::ConfigParser.parse(link_spec['properties'])
      end
    end
  end
end
