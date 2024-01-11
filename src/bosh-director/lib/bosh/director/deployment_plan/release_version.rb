module Bosh::Director
  module DeploymentPlan
    class ReleaseVersion
      extend ValidationHelper

      # @return [String] Release name
      attr_reader :name
      # @return [String] Release version
      attr_reader :version
      # @return [Models::ReleaseVersion] Release version model
      attr_reader :model
      # @return [ReleaseVersionExportedFrom] Stemcell object
      attr_reader :exported_from

      # @param [Models::Deployment] deployment_model Deployment model
      # @param [Hash] spec Release spec
      def self.parse(deployment_model, spec)
        name = safe_property(spec, 'name', class: String)
        version = safe_property(spec, 'version', class: String)
        exported_from = safe_property(
          spec,
          'exported_from',
          class: Array,
          optional: true,
          default: [],
        ).map { |raw| ReleaseVersionExportedFrom.parse(raw) }

        new(deployment_model, name, version, exported_from)
      end

      # @param [Models::Deployment] deployment_model Deployment model
      # @param [String] name Name of the release
      # @param [String] version Version of the release
      # @param [Array] exported_from Stemcells that the release should be compiled against
      def initialize(deployment_model, name, version, exported_from)
        @deployment_model = deployment_model
        @name = name
        @version = version
        @exported_from = exported_from

        @model = nil
        @jobs = {}

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
        @logger.debug("Found release '#{@name}/#{@version}'")

        unless @deployment_model.release_versions.include?(@model)
          @logger.debug("Binding release '#{@name}/#{@version}' " +
                        "to deployment '#{@deployment_model.name}'")
          @deployment_model.add_release_version(@model)
        end
      end

      # Looks up package and template models in DB and binds them to this
      # release spec
      # @return [void]
      def bind_jobs
        # ReleaseVersion model needs to be known so we can look up its
        # templates
        if @model.nil?
          raise DirectorError, 'ReleaseVersion model not bound in release spec'
        end

        # By now job specs from the deployment manifest should
        # have been parsed, so we can assume @jobs contains
        # the list of jobs that need to be bound
        @jobs.each_value do |job|
          @logger.debug("Binding template '#{job.name}'")
          job.bind_models
          @logger.debug("Bound template '#{job.name}'")
        end
      end

      # @return [Hash] Hash representation
      def spec
        {
          'name' => @name,
          'version' => @version
        }
      end

      # Looks up up job model by job name.
      #
      # Here “template” is the old Bosh v1 name for “job”.
      #
      # @param [String] name Job name
      # @return [Models::Template]
      def get_template_model_by_name(name)
        @all_jobs ||= @model.templates.each_with_object({}) do |job, all_jobs|
          all_jobs[job.name] = job
        end

        @all_jobs[name]
      end

      # Looks up up package model by package name
      # @param [String] name Package name
      # @return [Models::Package]
      def get_package_model_by_name(name)
        @model.package_by_name(name)
      end

      # Adds a job to a list of jobs used by this release for the current
      # deployment.
      #
      # Here “template” is the old Bosh v1 name for “job”.
      #
      # @param [String] options Template name
      def get_or_create_template(name)
        @jobs[name] ||= Job.new(self, name)
      end

      # Return a given job, identified by name.
      #
      # Here “template” is the old Bosh v1 name for “job”.
      #
      # @param [String] name Job name
      # @return [DeploymentPlan::Job] Job with given name used by this
      #                               release (if any)
      def template(name)
        @jobs[name]
      end

      # Returns a list of jobs from the release that are used by the
      # deployment.
      #
      # Note that this is not the full list of all jobs existing in the
      # release, but a subset list of the jobs defined in that release that
      # are used by the current deployment, and thus included in its plan.
      #
      # Here “template” is the old Bosh v1 name for “job”.
      #
      # @return [Array<DeploymentPlan::Job>] List of the release jobs used by
      #                                      the deployment
      def templates
        @jobs.values
      end
    end
  end
end
