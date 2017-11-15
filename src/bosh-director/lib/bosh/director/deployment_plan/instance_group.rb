require 'bosh/director/deployment_plan/instance_group_spec_parser'
require 'bosh/template/property_helper'

module Bosh::Director
  module DeploymentPlan
    class InstanceGroup
      include Bosh::Template::PropertyHelper

      VALID_LIFECYCLE_PROFILES = %w(service errand)
      DEFAULT_LIFECYCLE_PROFILE = 'service'

      # started, stopped and detached are real states
      # (persisting in DB and reflecting target instance state)
      # recreate and restart are two virtual states
      # (both set  target instance state to "started" and set
      # appropriate instance spec modifiers)
      VALID_STATES = %w(started stopped detached recreate restart)

      # @return [String] Instance group name
      attr_accessor :name

      # @return [String] Lifecycle profile
      attr_accessor :lifecycle

      # @return [String] Instance group canonical name (mostly for DNS)
      attr_accessor :canonical_name

      attr_accessor :persistent_disk_collection

      # @return [DeploymentPlan::ReleaseVersion] Release this instance group belongs to
      attr_accessor :release

      # @return [DeploymentPlan::Stemcell]
      attr_accessor :stemcell

      # @return [DeploymentPlan::VmType]
      attr_accessor :vm_type

      # @return [DeploymentPlan::VmResources]
      attr_accessor :vm_resources

      # @return [DeploymentPlan::VmExtension]
      attr_accessor :vm_extensions

      # @return [DeploymentPlan::Env]
      attr_accessor :env

      attr_accessor :default_network

      # @return [Array<DeploymentPlan::Job] Jobs included on the instance group
      attr_accessor :jobs

      # @return [Hash] Instance group properties
      attr_accessor :properties

      # @return [Hash<String, DeploymentPlan::Package] Packages included on the instance group
      attr_accessor :packages

      # @return [DeploymentPlan::UpdateConfig] Instance group update settings
      attr_accessor :update

      # @return [Array<DeploymentPlan::Instance>] All instances
      attr_accessor :instances

      # @return [Array<Models::Instance>] List of excess instance models that
      #   are not needed for current deployment
      attr_accessor :unneeded_instances

      # @return [String] Expected instance group state
      attr_accessor :state

      # @return [Hash<Integer, String>] Individual instance expected states
      attr_accessor :instance_states

      # @return [String] deployment name the instance group belongs to
      attr_accessor :deployment_name

      attr_accessor :availability_zones

      attr_accessor :networks

      attr_accessor :migrated_from

      attr_accessor :desired_instances

      attr_accessor :did_change

      attr_reader :link_paths

      attr_reader :resolved_links

      def self.parse(plan, instance_group_spec, event_log, logger, parse_options = {})
        parser = InstanceGroupSpecParser.new(plan, event_log, logger)
        parser.parse(instance_group_spec, parse_options)
      end

      def initialize(logger)
        @logger = logger

        @release = nil
        @jobs = []
        @properties = nil # Actual instance group properties

        @instances = []
        @desired_instances = []
        @unneeded_instances = []
        @instance_states = {}
        @default_network = {}

        @packages = {}
        @link_paths = {}
        @resolved_links = {}
        @migrated_from = []
        @availability_zones = []

        @instance_plans = []

        @did_change = false
        @persistent_disk_collection = nil

        @deployment_name = nil
      end

      def self.is_legacy_spec?(instance_group_spec)
        !instance_group_spec.has_key?('templates')
      end

      def add_instance_plans(instance_plans)
        @instance_plans = instance_plans
      end

      def sorted_instance_plans
        @sorted_instance_plans ||= InstancePlanSorter.new(@logger)
                                   .sort(@instance_plans.reject(&:obsolete?))
      end

      def add_job(job_to_add)
        jobs.each do |job|
          if job_to_add.name == job.name
            raise "Colocated job '#{job_to_add.name}' is already added to the instance group '#{name}'."
          end
        end
        jobs << job_to_add
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
        job = {
          'name' => job_spec['template'],
          'version' => job_spec['version'],
          'sha1' => job_spec['sha1'],
          'blobstore_id' => job_spec['blobstore_id']
        }

        # Supporting 'template_scoped_properties' for legacy spec is going to be messy.
        # So we will support this feature if a user want to use legacy spec. If they
        # want to use properties per template, let them use the regular way of defining
        # templates, i.e. by using the 'templates' key
        job_spec['templates'] = [job]
      end


      def obsolete_instance_plans
        @instance_plans.select(&:obsolete?)
      end

      def instances # to preserve interface for UpdateStep -- switch to instance_plans eventually
        needed_instance_plans.map(&:instance)
      end

      def unignored_instance_plans
        needed_instance_plans.select { |instance_plan| !instance_plan.should_be_ignored? }
      end

      def needed_instance_plans
        sorted_instance_plans
      end

      def unneeded_instances
        obsolete_instance_plans.map(&:instance)
      end

      # Returns instance group spec as a Hash. To be used by all instances to
      # populate agent state.
      # @return [Hash] Hash representation
      def spec
        result = { 'name' => @name }

        if @jobs.size >= 1
          first_job = @jobs[0]
          result.merge!({
            'templates' => [],
            # --- Legacy ---
            'template' => first_job.name,
            'version' => first_job.version,
            'sha1' => first_job.sha1,
            'blobstore_id' => first_job.blobstore_id
          })

          if first_job.logs
            result['logs'] = first_job.logs
          end
          # --- /Legacy ---

          @jobs.each do |job|
            job_entry = {
              'name' => job.name,
              'version' => job.version,
              'sha1' => job.sha1,
              'blobstore_id' => job.blobstore_id
            }

            if job.logs
              job_entry['logs'] = job.logs
            end
            result['templates'] << job_entry
          end
          result
        end
      end

      def update_spec
        update.to_hash
      end

      # Returns package specs for all packages in the instances indexed by package
      # name. To be used by all instances to populate agent state.
      # @return [Hash<String, Hash>] All package specs indexed by package name
      def package_spec
        result = {}
        @packages.each do |name, package|
          result[name] = package.spec
        end

        result.select { |name, _| run_time_dependencies.include? name }
      end

      def instance(index)
        @instances[index]
      end

      # Returns the state of an instance by its index
      # @param [Integer] index Instance index
      # @return [String, nil] Instance state (nil if not specified)
      def state_for_instance(instance_model)
        @instance_states[instance_model.uuid] || @instance_states[instance_model.index.to_s] || @state
      end

      # Registers compiled package with this instance.
      # @param [Models::CompiledPackage] compiled_package_model Compiled package
      # @return [void]
      def use_compiled_package(compiled_package_model)
        compiled_package = CompiledPackage.new(compiled_package_model)
        @packages[compiled_package.name] = compiled_package
      end

      # Extracts only the properties needed by this instance group. This is decoupled from
      # parsing properties because templates need to be bound to their models
      # before 'bind_properties' is being called (as we persist instance group template
      # property definitions in DB).
      def bind_properties
        @properties = {}

        options = {
          :dns_record_names => get_dns_record_names
        }

        @jobs.each do |job|
          job.bind_properties(@name, @deployment_name, options)
          @properties[job.name] = job.properties[@name]
        end
      end

      def validate_package_names_do_not_collide!
        releases_by_package_names = {}

        jobs.each do |job|
          job.model.package_names.each do |package_name|
            package = job.model.release.packages.find{|p| p.name == package_name}

            releases_by_package_names[package_name] ||= {
              usages: []
            }

            releases_by_package_names[package_name][:usages] << {
              fingerprint: package.fingerprint,
              release: job.release.name,
              job: job.name,
            }
          end
        end

        releases_by_package_names.each do |package_name, packages|
          releases = packages[:usages].group_by{ |u| u[:fingerprint] }

          if releases.size > 1
            release1jobs, release2jobs = releases.values[0..1]

            raise JobPackageCollision,
              "Package name collision detected in instance group '#{@name}': "\
                  "job '#{release1jobs[0][:release]}/#{release1jobs[0][:job]}' depends on package '#{release1jobs[0][:release]}/#{package_name}', "\
                  "job '#{release2jobs[0][:release]}/#{release2jobs[0][:job]}' depends on '#{release2jobs[0][:release]}/#{package_name}'. " +
                'BOSH cannot currently collocate two packages with identical names from separate releases.'
          end
        end
      end

      def bind_instances(ip_provider)
        instances.each(&:ensure_model_bound)
        bind_instance_networks(ip_provider)
      end

      #TODO: Instance group should not be responsible for reserving IPs. Consider moving this somewhere else? Maybe in the consumer?
      def bind_instance_networks(ip_provider)
        needed_instance_plans
          .flat_map(&:network_plans)
          .reject(&:obsolete?)
          .reject(&:existing?)
          .each do |network_plan|
          reservation = network_plan.reservation
          ip_provider.reserve(reservation)
        end
      end

      def bind_new_variable_set(new_variable_set)
        unignored_instance_plans.each do |instance_plan|
          instance_plan.instance.desired_variable_set = new_variable_set
        end
      end

      def has_network?(network_name)
        networks.any? do |network|
          network.name == network_name
        end
      end

      def is_service?
        @lifecycle == 'service'
      end

      def is_errand?
        @lifecycle == 'errand'
      end

      def instance_plans_with_missing_vms
        needed_instance_plans.reject do |instance_plan|
          instance_plan.instance.vm_created? || instance_plan.instance.state == 'detached'
        end
      end

      def add_resolved_link(job_name, link_name, link_spec)
        @resolved_links[job_name] ||= {}
        @resolved_links[job_name][link_name] = sort_property(link_spec)
      end

      def link_path(job_name, link_name)
        @link_paths.fetch(job_name, {})[link_name]
      end

      def add_link_path(job_name, link_name, link_path)
        @link_paths[job_name] ||= {}
        @link_paths[job_name][link_name] = link_path
      end

      def compilation?
        false
      end

      def has_job?(name, release)
        @jobs.any? { |job| job.name == name && job.release.name == release }
      end

      def has_os?(os)
        @stemcell.os == os
      end

      # @return [Array<Models::VariableSet>] All variable sets of NON-obsolete instance_plan instances
      def referenced_variable_sets
        needed_instance_plans.map do |instance_plan|
          instance_plan.instance.desired_variable_set
        end
      end

      def default_network_name
        @default_network['gateway']
      end

      private

      def run_time_dependencies
        jobs.flat_map { |job| job.package_models }.uniq.map(&:name)
      end

      def get_dns_record_names
        result = []
        networks.map(&:name).each do |network_name|
          result << DnsNameGenerator.dns_record_name('*', @name, network_name, @deployment_name, Config.root_domain)
        end
        result.sort
      end
    end
  end
end
