module Bosh::Director

  class PropertyManager

    def create_property(deployment_name, property_name, value)
      property = Models::DeploymentProperty.new
      property.deployment = find_deployment(deployment_name)
      property.name = property_name
      property.value = value
      property.save

    rescue Sequel::ValidationFailed => e
      # TODO: this is consistent with UserManager but doesn't quite feel right
      if e.errors[[:name, :deployment_id]].include?(:unique)
        raise PropertyAlreadyExists.new(property_name, deployment_name)
      end
      invalid_property(e.errors)
    end

    def update_property(deployment_name, property_name, value)
      property = get_property(deployment_name, property_name)
      property.value = value
      property.save

    rescue Sequel::ValidationFailed => e
      invalid_property(e.errors)
    end

    def delete_property(deployment_name, property_name)
      get_property(deployment_name, property_name).destroy
    end

    def get_property(deployment_name, property_name)
      deployment = find_deployment(deployment_name)
      property = Models::DeploymentProperty.find(:deployment_id => deployment.id, :name => property_name)
      property || raise(PropertyNotFound.new(property_name, deployment.name))
    end

    def get_properties(deployment_name)
      Models::DeploymentProperty.filter(:deployment_id => find_deployment(deployment_name).id).all
    end

    private

    def invalid_property(errors)
      raise PropertyInvalid.new(errors.full_messages.sort.join(", "))
    end

    def find_deployment(name)
      deployment = Models::Deployment.find(:name => name)
      deployment || raise(DeploymentNotFound.new(name))
    end

  end
end
