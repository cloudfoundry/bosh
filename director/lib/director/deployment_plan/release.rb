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
          raise DirectorError, "Deployment not bound in the deployment plan"
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

      # This method takes in a name of a template or an array of template names
      # and will initialize TemplateSpec classes for each template.  It will
      # then return an array of these TemplateSec classes.
      # @param [String|Array] name_or_array Template name or names.
      # @return [Array] Returns an array of the TemplateSepc classes
      #     initialized to the name_or_array.
      def template(name_or_array)
        template_names = [name_or_array] unless name_or_array.is_a?(Array)
        templates = []
        template_names.each do |name|
          @templates[name] ||= TemplateSpec.new(name)
          templates.push(@templates[name])
        end
        templates
      end

      def templates
        @templates.values
      end
    end
  end
end