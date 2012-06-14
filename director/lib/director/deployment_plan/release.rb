# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class Release
      include ValidationHelper

      # @return [String] Release name
      attr_reader :name
      # @return [String] Release version
      attr_reader :version
      # @return [Models::ReleaseVersion] Release version model
      attr_reader :model

      # @param [DeploymentPlan] deployment_plan Deployment plan
      # @param [Hash] spec Raw release spec from the deployment
      #   manifest
      def initialize(deployment_plan, spec)
        @deployment_plan = deployment_plan

        @name = safe_property(spec, "name", :class => String)
        @version = safe_property(spec, "version", :class => String)

        @model = nil
        @templates = {}

        @logger = Config.logger
        @manager = Api::ReleaseManager.new
      end

      # Looks up release version in database and binds it to the deployment
      # @return [void]
      def bind_model
        deployment = @deployment_plan.model
        if deployment.nil?
          raise DirectorError, "Deployment not bound in deployment plan"
        end

        release = @manager.find_by_name(@name)
        @model = @manager.find_version(release, @version)
        @logger.debug("Found release `#{@name}/#{@version}'")

        unless deployment.release_versions.include?(@model)
          @logger.debug("Binding release `#{@name}/#{@version}' " +
                        "to deployment `#{deployment.name}'")
          deployment.add_release_version(@model)
        end
      end

      # @return [Hash] Hash representation
      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end

      # @param [String] name Template name
      def template(name)
        @templates[name] ||= TemplateSpec.new(name)
      end

      def templates
        @templates.values
      end
    end
  end
end