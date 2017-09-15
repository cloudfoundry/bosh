module Bosh::Director
  module Api
    class PropertyManager

      def create_property(deployment, property_name, value)
        property = Models::DeploymentProperty.new
        property.deployment = deployment
        property.name = property_name
        property.value = value
        property.save

      rescue Sequel::ValidationFailed => e

        if e.errors[[:name, :deployment_id]] && e.errors[[:name, :deployment_id]].include?(:unique)
          raise PropertyAlreadyExists,
                "Property '#{property_name}' already exists " +
                "for deployment '#{deployment.name}'"
        end
        invalid_property(e.errors)
      end

      def update_property(deployment, property_name, value)
        property = get_property(deployment, property_name)
        property.value = value
        property.save

      rescue Sequel::ValidationFailed => e
        invalid_property(e.errors)
      end

      def delete_property(deployment, property_name)
        get_property(deployment, property_name).destroy
      end

      def get_property(deployment, property_name)
        filters = {:deployment_id => deployment.id, :name => property_name}
        property = Models::DeploymentProperty.find(filters)
        if property.nil?
          raise PropertyNotFound,
                "Property '#{property_name}' not found " +
                "for deployment '#{deployment.name}'"
        end
        property
      end

      def get_properties(deployment)
        filters = {:deployment_id => deployment.id}
        Models::DeploymentProperty.filter(filters).all
      end

      private

      def invalid_property(errors)
        raise PropertyInvalid,
              "Property is invalid: #{errors.full_messages.sort.join(", ")}"
      end
    end
  end
end
