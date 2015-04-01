# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class PropertyManager

      def initialize(deployment_manager)
        @deployment_manager = deployment_manager
      end

      def create_property(deployment_name, property_name, value)
        property = Models::DeploymentProperty.new
        property.deployment = find_deployment(deployment_name)
        property.name = property_name
        property.value = value
        property.save

      rescue Sequel::ValidationFailed => e
        if e.errors[[:name, :deployment_id]].include?(:unique)
          raise PropertyAlreadyExists,
                "Property `#{property_name}' already exists " +
                "for deployment `#{deployment_name}'"
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
        filters = {:deployment_id => deployment.id, :name => property_name}
        property = Models::DeploymentProperty.find(filters)
        if property.nil?
          raise PropertyNotFound,
                "Property `#{property_name}' not found " +
                "for deployment `#{deployment_name}'"
        end
        property
      end

      def get_properties(deployment_name)
        filters = {:deployment_id => find_deployment(deployment_name).id}
        Models::DeploymentProperty.filter(filters).all
      end

      private

      def invalid_property(errors)
        raise PropertyInvalid,
              "Property is invalid: #{errors.full_messages.sort.join(", ")}"
      end

      def find_deployment(name)
        @deployment_manager.find_by_name(name)
      end
    end
  end
end