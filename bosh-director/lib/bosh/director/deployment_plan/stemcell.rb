# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    class Stemcell
      include ValidationHelper

      # @return [String] Stemcell name
      attr_reader :name

      # @return [String] Stemcell version
      attr_reader :version

      # @return [Models::Stemcell] Stemcell DB model
      attr_reader :model

      # @param [Hash] spec Raw stemcell spec according to deployment manifest
      def initialize(spec)
        @name = safe_property(spec, "name", :class => String)
        @version = safe_property(spec, "version", :class => String)

        @manager = Api::StemcellManager.new
        @model = nil
      end

      # Looks up the stemcell matching provided spec
      # @return [void]
      def bind_model(deployment_plan)
        deployment_model = deployment_plan.model
        if deployment_model.nil?
          raise DirectorError, "Deployment not bound in the deployment plan"
        end

        @model = @manager.find_by_name_and_version(@name, @version)

        unless @model.deployments.include?(deployment_model)
          @model.add_deployment(deployment_model)
        end
      end

      def desc
        @model.desc
      end

      def cid
        @model.cid
      end

      def id
        @model.id
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
