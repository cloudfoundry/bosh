require 'bosh/director/deployment_plan/instance_group_spec_parser'
require 'bosh/template/property_helper'

module Bosh::Director
  module DeploymentPlan
    class InstanceGroup
      include Bosh::Template::PropertyHelper

      VALID_LIFECYCLE_PROFILES = %w[service errand].freeze
      DEFAULT_LIFECYCLE_PROFILE = 'service'.freeze

      # started, stopped and detached are real states
      # (persisting in DB and reflecting target instance state)
      # recreate and restart are two virtual states
      # (both set  target instance state to "started" and set
      # appropriate instance spec modifiers)
      VALID_STATES = %w[started stopped detached recreate restart].freeze

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

      # @return [Array<DeploymentPlan::Job>] Jobs included on the instance group
      attr_accessor :jobs

      # @return [Hash] Instance group properties
      attr_accessor :properties

      # @return [Hash<String, DeploymentPlan::Package>] Packages included on the instance group
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
        @migrated_from = []
        @availability_zones = []

        @instance_plans = []

        @did_change = false
        @persistent_disk_collection = PersistentDiskCollection.new(@logger)

        @deployment_name = nil
      end

      def self.legacy_spec?(instance_group_spec)
        !instance_group_spec.key?('templates')
      end

      def add_instance_plans(instance_plans)
        @instance_plans = instance_plans
      end

      def sorted_instance_plans
        @sorted_instance_plans ||= InstancePlanSorter.new(@logger)
                                                     .sort(@instance_plans.reject(&:obsolete?))
      end

      def unignored_instance_plans_needing_duplicate_vm
        @shutdown_instances ||= sorted_instance_plans.select { |plan| plan.instance&.vm_created? }
                                                     .select(&:needs_duplicate_vm?)
                                                     .reject(&:new?)
                                                     .reject(&:should_be_ignored?)
                                                     .reject { |plan| plan.instance.state == 'detached' }
      end

      def add_job(job_to_add)
        jobs.each do |job|
          if job_to_add.name == job.name
            raise "Colocated job '#{job_to_add.name}' is already added to the instance group '#{name}'."
          end
        end
        jobs << job_to_add
      end

      def obsolete_instance_plans
        @instance_plans.select(&:obsolete?)
      end

      # to preserve interface for UpdateStage -- switch to instance_plans eventually
      def instances
        needed_instance_plans.map(&:instance)
      end

      def unignored_instance_plans
        needed_instance_plans.reject(&:should_be_ignored?)
      end

      def vm_strategy
        update&.vm_strategy
      end

      def create_swap_delete?
        vm_strategy == UpdateConfig::VM_STRATEGY_CREATE_SWAP_DELETE
      end

      def should_create_swap_delete?
        Array(networks).none?(&:static?) && create_swap_delete?
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
        result = { 'name' => @name, 'templates' => [] }

        return nil if @jobs.empty?

        default_errand = @jobs.first
        result['template'] = default_errand.name
        result['version'] = default_errand.version

        @jobs.each do |job|
          job_entry = {
            'name' => job.name,
            'version' => job.version,
            'sha1' => job.sha1,
            'blobstore_id' => job.blobstore_id,
          }

          job_entry['logs'] = job.logs if job.logs
          result['templates'] << job_entry
        end

        result
      end

      def update_spec
        update.to_hash
      end

      # Returns package specs for all packages in the instances indexed by package
      # name. To be used by all instances to populate agent state.
      # @return [Hash<String, Hash>] All package specs indexed by package name
      def package_spec
        @packages.each_with_object({}) do |(name, package), acc|
          acc[name] = package.spec
        end.select { |name, _| run_time_dependencies.include? name }
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

        return unless run_time_packages.include?(compiled_package_model.package)
        return if newer_package_known_than(compiled_package)

        @packages[compiled_package.name] = compiled_package
      end

      # Extracts only the properties needed by this instance group. This is decoupled from
      # parsing properties because templates need to be bound to their models
      # before 'bind_properties' is being called (as we persist instance group template
      # property definitions in DB).
      def bind_properties
        @properties = @jobs.each_with_object({}) do |job, acc|
          job.bind_properties(@name)
          acc[job.name] = job.properties[@name]
        end
      end

      def validate_exported_from_matches_stemcell!
        jobs.each do |job|
          next if job.release.exported_from.empty?

          next if compatible_exported_from?(job.release.exported_from, stemcell)

          msg = "Invalid release detected in instance group '#{@name}' using stemcell '#{stemcell.desc}': "\
                "release '#{job.release.name}' must be exported from stemcell '#{stemcell.desc}'. "\
                "Release '#{job.release.name}' is exported from: #{get_incompatible_exported_from(job.release.exported_from)}."
          raise JobWithExportedFromMismatch, msg

        end
      end

      def validate_package_names_do_not_collide!
        releases_by_package_names = {}

        jobs.each do |job|
          job.model.package_names.each do |package_name|
            package = job.release.model.packages.find { |p| p.name == package_name }

            releases_by_package_names[package_name] ||= {
              usages: [],
            }

            releases_by_package_names[package_name][:usages] << {
              fingerprint: package.fingerprint,
              dependency_set_json: package.dependency_set_json,
              release: job.release.name,
              job: job.name,
            }
          end
        end

        releases_by_package_names.each do |package_name, packages|
          releases = packages[:usages].group_by { |u| u[:fingerprint] + u[:dependency_set_json] }

          next unless releases.size > 1

          release1jobs, release2jobs = releases.values[0..1]

          raise JobPackageCollision,
                "Package name collision detected in instance group '#{@name}': " \
                    "job '#{release1jobs[0][:release]}/#{release1jobs[0][:job]}' " \
                    "depends on package '#{release1jobs[0][:release]}/#{package_name}' " \
                        "with fingerprint '#{release1jobs[0][:fingerprint]}', " \
                    "job '#{release2jobs[0][:release]}/#{release2jobs[0][:job]}' " \
                    "depends on package '#{release2jobs[0][:release]}/#{package_name}' " \
                        "with fingerprint '#{release2jobs[0][:fingerprint]}'. " \
                'BOSH cannot currently collocate two packages with identical names and different fingerprints or dependencies.'
        end
      end

      def bind_instances(ip_provider)
        instances.each(&:ensure_model_bound)
        bind_instance_networks(ip_provider)
      end

      # TODO: Instance group should not be responsible for reserving IPs.
      # Consider moving this somewhere else? Maybe in the consumer?
      def bind_instance_networks(ip_provider)
        needed_instance_plans
          .flat_map(&:network_plans)
          .reject(&:obsolete?)
          .reject(&:existing?)
          .each do |network_plan|
            ip_provider.reserve(network_plan.reservation)
          end
      end

      def bind_new_variable_set(new_variable_set)
        unignored_instance_plans.each do |instance_plan|
          instance_plan.instance.desired_variable_set = new_variable_set
        end
      end

      def network_present?(network_name)
        networks.any? do |network|
          network.name == network_name
        end
      end

      def service?
        @lifecycle == 'service'
      end

      def errand?
        @lifecycle == 'errand'
      end

      def instance_plans_with_missing_vms
        needed_instance_plans.reject do |instance_plan|
          instance_plan.instance.vm_created? || instance_plan.instance.state == 'detached'
        end
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
        @default_network['addressable'] || @default_network['gateway']
      end

      def has_availability_zone?(az_name)
        availability_zones.any? do |availability_zone|
          availability_zone.name == az_name
        end
      end

      private

      def run_time_dependencies
        run_time_packages.map(&:name)
      end

      def run_time_packages
        jobs.flat_map(&:package_models).uniq
      end

      def dns_record_names
        networks.map do |network|
          DnsNameGenerator.dns_record_name('*', @name, network.name, @deployment_name, Config.root_domain)
        end.sort
      end

      def newer_package_known_than(package)
        @packages[package.name]&.model&.id.to_i >= package.model.id
      end

      def compatible_exported_from?(exported_from_list, stemcell)
        exported_from_list.any? do |exported_from|
          exported_from.compatible_with?(stemcell)
        end
      end

      def get_incompatible_exported_from(exported_from_list)
        stemcells = []
        exported_from_list.each do |exported_from|
          stemcells << "'#{exported_from.os}/#{exported_from.version}'"
        end
        stemcells.join(', ')
      end
    end
  end
end
