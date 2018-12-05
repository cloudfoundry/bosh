module Bosh::Director
  module Api
    class VariableRotationManager
      def initialize(manifest_variables, deployment_name)
        @variables = manifest_variables
        @deployment_name = deployment_name
      end

      def regenerate_leaf_certificates
        client = Bosh::Director::ConfigServer::ClientFactory.create_default_client
        regenerated = []
        variable_leaf_certificates do |leaf|
          client.force_regenerate_value(leaf['absolute_name'], leaf['type'], leaf['options'])
          regenerated << { 'name' => leaf['absolute_name'], 'type' => 'variable' }
        end
        regenerated
      end

      def deployment_leaf_certificates
        leaf_certificates = []
        variable_leaf_certificates do |leaf|
          leaf_certificates << { 'name' => leaf['absolute_name'], 'type' => 'variable' }
        end
        leaf_certificates
      end

      def variable_leaf_certificates
        @variables.each do |variable|
          next if variable['type'] != 'certificate' || variable['options']['is_ca']

          options = variable['options']
          absolute_name = Bosh::Director::ConfigServer::ConfigServerHelper.add_prefix_if_not_absolute(
            variable['name'],
            Bosh::Director::Config.name, @deployment_name
          )
          variable['absolute_name'] = absolute_name
          variable['options']['ca'] = Bosh::Director::ConfigServer::ConfigServerHelper.add_prefix_if_not_absolute(
            options['ca'],
            Bosh::Director::Config.name, @deployment_name
          )
          yield variable
        end
      end
    end
  end
end
