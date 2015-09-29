# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    class Stemcell
      include ValidationHelper

      attr_reader :alias
      attr_reader :os

      # @return [String] Stemcell name
      attr_reader :name

      # @return [String] Stemcell version
      attr_reader :version

      # @return [Models::Stemcell] Stemcell DB model
      attr_reader :model

      # @param [Hash] spec Raw stemcell spec according to deployment manifest
      def initialize(spec)
        @alias = safe_property(spec, "alias", :class => String, :optional => true)

        @name = safe_property(spec, "name", :class => String, :optional => true)
        @os = safe_property(spec, "os", :class => String, :optional => true)

        if @name.nil? && @os.nil?
          raise ValidationMissingField, "An OS or a name must be specified for a stemcell"
        end

        if !@name.nil? && !@os.nil?
          raise StemcellBothNameAndOS, "An OS and a name are both specified for a stemcell name: #{@name} and OS: #{os}"
        end

        @version = safe_property(spec, "version", :class => String)

        @manager = Api::StemcellManager.new
        @model = nil
      end

      def is_using_latest_version?
        @version == 'latest'
      end

      # Looks up the stemcell matching provided spec
      # @return [void]
      def bind_model(deployment_plan)
        deployment_model = deployment_plan.model
        if deployment_model.nil?
          raise DirectorError, "Deployment not bound in the deployment plan"
        end

        if is_using_latest_version?
          @model = @manager.latest_by_name(@name)
          @version = @model.version
        else
          @model = @manager.find_by_name_and_version(@name, @version)
        end

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
