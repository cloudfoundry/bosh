require 'bosh/director/deployment_plan/job_spec_parser'

module Bosh::Director
  module DeploymentPlan
    class Job
      include Bosh::Common::PropertyHelper

      # started, stopped and detached are real states
      # (persisting in DB and reflecting target instance state)
      # recreate and restart are two virtual states
      # (both set  target instance state to "started" and set
      # appropriate instance spec modifiers)
      VALID_JOB_STATES = %w(started stopped detached recreate restart)

      # @return [String] Job name
      attr_accessor :name

      # @return [String] Job canonical name (mostly for DNS)
      attr_accessor :canonical_name

      # @return [Integer] Persistent disk size (no disk if zero)
      attr_accessor :persistent_disk

      # @return [DeploymentPlan] Current deployment plan
      attr_accessor :deployment

      # @return [DeploymentPlan::ReleaseVersion] Release this job belongs to
      attr_accessor :release

      # @return [DeploymentPlan::ResourcePool] Resource pool this job should
      #   be run in
      attr_accessor :resource_pool

      # @return [DeploymentPlan::Network Job default network
      attr_accessor :default_network

      # @return [Array<DeploymentPlan::Template] Templates included into the job
      attr_accessor :templates

      # @return [Hash] Job properties
      attr_accessor :properties

      # @return [Hash<String, DeploymentPlan::Package] Packages included into
      #   this job
      attr_accessor :packages

      # @return [DeploymentPlan::UpdateConfig] Job update settings
      attr_accessor :update

      # @return [Array<DeploymentPlan::Instance>] All job instances
      attr_accessor :instances

      # @return [Array<Models::Instance>] List of excess instance models that
      #   are not needed for current deployment
      attr_accessor :unneeded_instances

      # @return [String] Expected job state
      attr_accessor :state

      # @return [Hash<Integer, String>] Individual instance expected states
      attr_accessor :instance_states

      # @return [Exception] Exception that requires job update process to be
      #   interrupted
      attr_accessor :halt_exception

      attr_accessor :all_properties

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      # @param [Hash] job_spec Raw job spec from the deployment manifest
      # @return [Bosh::Director::DeploymentPlan::Job]
      def self.parse(deployment, job_spec)
        job_parser = JobSpecParser.new(deployment)
        job_parser.parse(job_spec)
      end

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      def initialize(deployment)
        @deployment = deployment

        @release = nil
        @templates = []
        @all_properties = nil # All properties available to job
        @properties = nil # Actual job properties

        @instances = []
        @unneeded_instances = []
        @instance_states = {}

        @error_mutex = Mutex.new
        @packages = {}
        @halt = false
      end

      def self.is_legacy_spec?(job_spec)
        !job_spec.has_key?("templates")
      end

      # Takes in a job spec and returns a job spec in the new format, if it
      # needs to be modified.  The new format has "templates" key, which is an
      # array with each template's data.  This is used for job collocation,
      # specifically for the agent's current job spec when compared to the
      # director's.  We only convert their template to a single array entry
      # because it should be impossible for the agent to have a job spec with
      # multiple templates in legacy form.
      def self.convert_from_legacy_spec(job_spec)
        return job_spec if !self.is_legacy_spec?(job_spec)
        template = {
          "name" => job_spec["template"],
          "version" => job_spec["version"],
          "sha1" => job_spec["sha1"],
          "blobstore_id" => job_spec["blobstore_id"]
        }
        job_spec["templates"] = [template]
      end

      # Returns job spec as a Hash. To be used by all instances of the job to
      # populate agent state.
      # @return [Hash] Hash representation
      def spec
        first_template = @templates[0]
        result = {
          "name" => @name,
          "templates" => [],
          # --- Legacy ---
          "template" => first_template.name,
          "version" => first_template.version,
          "sha1" => first_template.sha1,
          "blobstore_id" => first_template.blobstore_id
        }
        if first_template.logs
          result["logs"] = first_template.logs
        end
        # --- /Legacy ---

        @templates.each do |template|
          template_entry = {
            "name" => template.name,
            "version" => template.version,
            "sha1" => template.sha1,
            "blobstore_id" => template.blobstore_id
          }
          if template.logs
            template_entry["logs"] = template.logs
          end
          result["templates"] << template_entry
        end

        result
      end

      # Returns package specs for all packages in the job indexed by package
      # name. To be used by all instances of the job to populate agent state.
      # @return [Hash<String, Hash>] All package specs indexed by package name
      def package_spec
        result = {}
        @packages.each do |name, package|
          result[name] = package.spec
        end

        result.select { |name, _| run_time_dependencies.include? name }
      end

      # Returns job instance by index
      # @param [Integer] index
      # @return [DeploymentPlan::Instance] index-th instance
      def instance(index)
        @instances[index]
      end

      # Returns the state state of job instance by its index
      # @param [Integer] index Instance index
      # @return [String, nil] Instance state (nil if not specified)
      def instance_state(index)
        @instance_states[index] || @state
      end

      # Registers compiled package with this job.
      # @param [Models::CompiledPackage] compiled_package_model Compiled package
      # @return [void]
      def use_compiled_package(compiled_package_model)
        compiled_package = CompiledPackage.new(compiled_package_model)
        @packages[compiled_package.name] = compiled_package
      end

      def should_halt?
        @halt
      end

      def record_update_error(error, options = {})
        @error_mutex.synchronize do
          @halt = true
          @halt_exception = error
        end
      end

      # Extracts only the properties needed by this job. This is decoupled from
      # parsing properties because templates need to be bound to their models
      # before 'bind_properties' is being called (as we persist job template
      # property definitions in DB).
      def bind_properties
        @properties = filter_properties(@all_properties)
      end

      def validate_package_names_do_not_collide!
        releases_by_package_names = templates
          .reduce([]) { |memo, t| memo + t.model.package_names.product([t.release]) }
          .reduce({}) { |memo, package_name_and_release_version|
            package_name = package_name_and_release_version.first
            release_version = package_name_and_release_version.last
            memo[package_name] ||= Set.new
            memo[package_name] << release_version
            memo
          }

        releases_by_package_names.each do |package_name, releases|
          if releases.size > 1
            release1, release2 = releases.to_a[0..1]
            offending_template1 = templates.find { |t| t.release == release1 }
            offending_template2 = templates.find { |t| t.release == release2 }

            raise JobPackageCollision,
                  "Package name collision detected in job `#{@name}': "\
                  "template `#{release1.name}/#{offending_template1.name}' depends on package `#{release1.name}/#{package_name}', "\
                  "template `#{release2.name}/#{offending_template2.name}' depends on `#{release2.name}/#{package_name}'. " +
                  'BOSH cannot currently collocate two packages with identical names from separate releases.'
          end
        end
      end

      private

      # @param [Hash] collection All properties collection
      # @return [Hash] Properties required by templates included in this job
      def filter_properties(collection)
        if @templates.empty?
          raise DirectorError, "Can't extract job properties before parsing job templates"
        end

        if @templates.none? { |template| template.properties }
          return collection
        end

        if @templates.all? { |template| template.properties }
          return extract_template_properties(collection)
        end

        raise JobIncompatibleSpecs,
          "Job `#{name}' has specs with conflicting property definition styles between" +
          " its job spec templates.  This may occur if colocating jobs, one of which has a spec file including" +
          " `properties' and one which doesn't."
      end

      def extract_template_properties(collection)
        result = {}

        @templates.each do |template|
          template.properties.each_pair do |name, definition|
            copy_property(result, collection, name, definition["default"])
          end
        end

        result
      end

      def run_time_dependencies
        templates.flat_map { |template| template.package_models }.uniq.map(&:name)
      end
    end
  end
end
