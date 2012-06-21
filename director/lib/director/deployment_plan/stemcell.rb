# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class Stemcell
      include ValidationHelper

      # @return [DeploymentPlan::ResourcePool] Resource pool
      attr_reader :resource_pool

      # @return [String] Stemcell name
      attr_reader :name

      # @return [String] Stemcell version
      attr_reader :version

      # @return [Models::Stemcell] Stemcell DB model
      attr_reader :model

      # @param [DeploymentPlan::ResourcePool] resource_pool Resource pool
      #   this stemcell belongs to
      # @param [Hash] spec Raw stemcell spec according to deployment manifest
      def initialize(resource_pool, spec)
        @resource_pool = resource_pool
        @name = safe_property(spec, "name", :class => String)
        @version = safe_property(spec, "version", :class => String)

        @manager = Api::StemcellManager.new
        @model = nil
      end

      # Looks up the stemcell matching provided spec
      # @return [void]
      def bind_model
        deployment = @resource_pool.deployment_plan.model
        if deployment.nil?
          raise DirectorError, "Deployment not bound in the deployment plan"
        end

        @model = @manager.find_by_name_and_version(@name, @version)

        unless @model.deployments.include?(deployment)
          @model.add_deployment(deployment)
        end
      end

      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end

    end
  end
end