module Bosh::Director
  module DeploymentPlan
    class ReleaseVersion
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
      def initialize(deployment_model, spec)
        @deployment_model = deployment_model

        @name = safe_property(spec, 'name', :class => String)
        @version = safe_property(spec, 'version', :class => String)

        @model = nil
        @templates = {}

        @logger = Config.logger
        @manager = Api::ReleaseManager.new
      end

      # Looks up release version in database and binds it to the deployment
      # @return [void]
      def bind_model
        if @deployment_model.nil?
          raise DirectorError, 'Deployment not bound in the deployment plan'
        end

        release = @manager.find_by_name(@name)
        @model = @manager.find_version(release, @version)
        @logger.debug("Found release `#{@name}/#{@version}'")

        unless @deployment_model.release_versions.include?(@model)
          @logger.debug("Binding release `#{@name}/#{@version}' " +
                        "to deployment `#{@deployment_model.name}'")
          @deployment_model.add_release_version(@model)
        end
      end

      # Looks up package and template models in DB and binds them to this
      # release spec
      # @return [void]
      def bind_templates
        # ReleaseVersion model needs to be known so we can look up its
        # templates
        if @model.nil?
          raise DirectorError, 'ReleaseVersion model not bound in release spec'
        end

        # By now job specs from the deployment manifest should
        # have been parsed, so we can assume @templates contains
        # the list of templates that need to be bound
        @templates.each_value do |template|
          @logger.debug("Binding template `#{template.name}'")
          template.bind_models
          @logger.debug("Bound template `#{template.name}'")
        end
      end

      # @return [Hash] Hash representation
      def spec
        {
          'name' => @name,
          'version' => @version
        }
      end

      # Looks up up template model by template name
      # @param [String] name Template name
      # @return [Models::Template]
      def get_template_model_by_name(name)
        @all_templates ||= @model.templates.inject({}) do |hash, template|
          hash[template.name] = template
          hash
        end

        @all_templates[name]
      end

      # Looks up up package model by package name
      # @param [String] name Package name
      # @return [Models::Package]
      def get_package_model_by_name(name)
        @model.package_by_name(name)
      end

      # Adds template to a list of templates used by this release for the
      # current deployment
      # @param [String] template_name Template name
      def use_template_named(template_name)
        @templates[template_name] ||= Template.new(self, template_name)
      end

      # @param [String] name Template name
      # @return [DeploymentPlan::Template] Template with given name used by this
      #   release (if any)
      def template(name)
        @templates[name]
      end

      # Returns a list of job templates that need to be included into this
      # release. Note that this is not just a list of all templates existing
      # in the release but rather a list of templates for jobs that are included
      # into current deployment plan.
      # @return [Array<DeploymentPlan::Template>] List of job templates
      def templates
        @templates.values
      end
    end
  end
end
