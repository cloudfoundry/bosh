require 'bosh/template/property_helper'

module Bosh::Director
  module DeploymentPlan
    class InstanceGroupSpecParser
      include ValidationHelper
      include Bosh::Template::PropertyHelper
      include IpUtil

      MANUAL_LINK_KEYS = %w[instances properties address].freeze

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      def initialize(deployment, instance_group_spec, event_log, logger)
        @deployment = deployment
        @event_log = event_log
        @logger = logger
        @links_parser = Bosh::Director::Links::LinksParser.new
        @instance_group_spec = instance_group_spec
      end

      # @param [Hash] instance_group_spec Raw instance_group spec from the deployment manifest
      # @return [DeploymentPlan::InstanceGroup] Instance groups as built from instance_group_spec
      def parse(options = {})
        name = safe_property(@instance_group_spec, 'name', class: String)
        lifecycle = parse_lifecycle(name)

        validate_instance_group(name)

        jobs = parse_jobs(name, options['is_deploy_action'])
        check_job_uniqueness(name, jobs)

        persistent_disk_collection = parse_disks(name)

        stemcell = parse_stemcell(name)
        vm_resources, vm_type = parse_vm_type(name)
        vm_extensions = parse_vm_extensions

        env = parse_env

        update = parse_update_config(options)

        networks = InstanceGroupNetworksParser.new(
          Network::REQUIRED_DEFAULTS,
          Network::OPTIONAL_DEFAULTS,
        ).parse(@instance_group_spec, name, @deployment.networks)
        default_networks = assign_default_networks(networks)

        availability_zones = InstanceGroupAvailabilityZoneParser.new.parse(@instance_group_spec, name, @deployment, networks)

        migrated_from = parse_migrated_from(name, availability_zones)

        state = parse_state(name)
        instance_states = parse_instance_states(name)

        num_desired_instances = parse_desired_instances(name, networks)

        tags = safe_property(@instance_group_spec, 'tags', class: Hash, default: {})

        instance_group = InstanceGroup.new(
          name: name,
          canonical_name: Canonicalizer.canonicalize(name),
          lifecycle: lifecycle,
          jobs: jobs,
          persistent_disk_collection: persistent_disk_collection,
          env: env,
          stemcell: stemcell,
          vm_type: vm_type,
          vm_resources: vm_resources,
          vm_extensions: vm_extensions,
          update: update,
          networks: networks,
          default_network: default_networks,
          availability_zones: availability_zones,
          migrated_from: migrated_from,
          state: state,
          instance_states: instance_states,
          deployment_name: @deployment.name,
          logger: @logger,
          tags: tags
        )

        instance_group.create_desired_instances(num_desired_instances, @deployment)
        instance_group
      end

      private

      def parse_lifecycle(name)
        lifecycle = safe_property(@instance_group_spec, 'lifecycle',
                                  class: String,
                                  optional: true,
                                  default: InstanceGroup::DEFAULT_LIFECYCLE_PROFILE)

        unless InstanceGroup::VALID_LIFECYCLE_PROFILES.include?(lifecycle)
          raise JobInvalidLifecycle,
                "Invalid lifecycle '#{lifecycle}' for '#{name}', " \
                "valid lifecycle profiles are: #{InstanceGroup::VALID_LIFECYCLE_PROFILES.join(', ')}"
        end

        lifecycle
      end

      def parse_jobs(name, is_deploy_action)
        jobs = safe_property(@instance_group_spec, 'jobs', class: Array)
        instance_group_properties = extract_global_and_instance_group_properties
        migrated_from = safe_property(@instance_group_spec, 'migrated_from', class: Array, default: [])

        release_manager = Api::ReleaseManager.new

        # Key: release name.
        # Value: list of templates models of release version.
        release_versions_templates_models_hash = {}

        jobs.map do |job_spec|
          job_name = safe_property(job_spec, 'name', class: String)
          release_name = safe_property(job_spec, 'release', class: String)

          release = @deployment.release(release_name)
          unless release
            raise InstanceGroupUnknownRelease,
                  "Job '#{job_name}' (instance group '#{name}') references an unknown release '#{release_name}'"
          end

          release_model = release_manager.find_by_name(release.name)
          current_release_version = release_manager.find_version(release_model, release.version)
          release_versions_templates_models_hash[release_name] = current_release_version.templates

          current_template_model = current_release_version.templates.find { |target| target.name == job_name }

          job = release.get_or_create_template(job_name)

          raise ReleaseMissingJob, "Job '#{job_name}' not found in release '#{release.name}'" if current_template_model.nil?

          job_properties = safe_property(job_spec, 'properties', class: Hash, default: instance_group_properties)
          job.add_properties(job_properties, name)

          # Don't recalculate links on actions that aren't a deploy
          if is_deploy_action
            @links_parser.parse_providers_from_job(
              job_spec,
              @deployment.model,
              current_template_model,
              job_properties: job_properties,
              instance_group_name: name,
              migrated_from: migrated_from,
            )
            @links_parser.parse_consumers_from_job(
              job_spec,
              @deployment.model,
              current_template_model,
              instance_group_name: name,
              migrated_from: migrated_from,
            )
          end
          job
        end
      end

      def extract_global_and_instance_group_properties
        # Manifest can contain global and per-instance_group properties section
        instance_group_properties = safe_property(@instance_group_spec, 'properties', class: Hash, optional: true, default: {})
        @deployment.properties.recursive_merge(instance_group_properties)
      end

      def check_job_uniqueness(name, jobs)
        all_names = jobs.map(&:name)
        jobs.each do |job|
          if all_names.count(job.name) > 1
            raise InstanceGroupInvalidJobs,
                  "Colocated job '#{job.name}' is already added to the instance group '#{name}'"
          end
        end
      end

      def parse_disks(name)
        disk_size = safe_property(@instance_group_spec, 'persistent_disk', class: Integer, optional: true)
        disk_type_name = safe_property(@instance_group_spec, 'persistent_disk_type', class: String, optional: true)
        disk_pool_name = safe_property(@instance_group_spec, 'persistent_disk_pool', class: String, optional: true)
        persistent_disks = safe_property(@instance_group_spec, 'persistent_disks', class: Array, optional: true)

        if disk_pool_name
          raise V1DeprecatedDiskPools,
                '`persistent_disk_pool` is not supported as an `instance_groups` key. Please use `persistent_disk_type` instead.'
        end

        if [disk_size, disk_type_name, persistent_disks].compact!.size > 1
          raise InstanceGroupInvalidPersistentDisk,
                "Instance group '#{name}' specifies more than one of the following keys:" \
                " 'persistent_disk', 'persistent_disk_type', and 'persistent_disks'. Choose one."
        end

        persistent_disk_collection = PersistentDiskCollection.new(@logger)

        if disk_size
          if disk_size < 0
            raise InstanceGroupInvalidPersistentDisk,
                  "Instance group '#{name}' references an invalid persistent disk size '#{disk_size}'"
          end

          persistent_disk_collection.add_by_disk_size(disk_size) unless disk_size == 0
        end

        if disk_type_name
          disk_type = @deployment.disk_type(disk_type_name)
          if disk_type.nil?
            raise InstanceGroupUnknownDiskType,
                  "Instance group '#{name}' references an unknown disk type '#{disk_type_name}'"
          end

          persistent_disk_collection.add_by_disk_type(disk_type)
        end

        if persistent_disks
          unique_names = persistent_disks.map { |persistent_disk| persistent_disk['name'] }.uniq
          if unique_names.size != persistent_disks.size
            raise InstanceGroupInvalidPersistentDisk,
                  "Instance group '#{name}' persistent_disks's section contains duplicate names"
          end

          persistent_disks.each do |persistent_disk|
            disk_type_name = persistent_disk['type']
            disk_type = @deployment.disk_type(disk_type_name)
            if disk_type.nil?
              raise InstanceGroupUnknownDiskType,
                    "Instance group '#{name}' persistent_disks's section references an unknown disk type '#{disk_type_name}'"
            end

            persistent_disk_name = persistent_disk['name']
            if persistent_disk_name.blank?
              raise InstanceGroupInvalidPersistentDisk,
                    "Instance group '#{name}' persistent_disks's section contains a disk with no name"
            end

            persistent_disk_collection.add_by_disk_name_and_type(persistent_disk_name, disk_type)

            @links_parser.parse_provider_from_disk(persistent_disk, @deployment.model, name)
          end
        end

        persistent_disk_collection
      end

      def parse_stemcell(name)
        stemcell_name = safe_property(@instance_group_spec, 'stemcell', class: String)
        stemcell = @deployment.stemcell(stemcell_name)
        if stemcell.nil?
          raise InstanceGroupUnknownStemcell,
                "Instance group '#{name}' references an unknown stemcell '#{stemcell_name}'"
        end
        stemcell
      end

      def parse_vm_type(name)
        resource_pool_name = safe_property(@instance_group_spec, 'resource_pool', class: String, optional: true)

        if resource_pool_name
          raise V1DeprecatedResourcePool,
                "Instance groups no longer support resource_pool, please use 'vm_type' or 'vm_resources' keys"
        end

        vm_type_name = safe_property(@instance_group_spec, 'vm_type', class: String, optional: true)
        vm_resources = safe_property(@instance_group_spec, 'vm_resources', class: Hash, optional: true)

        statement_count = [vm_type_name, vm_resources].compact.count
        raise_vm_configuration_error(name, statement_count) if statement_count != 1

        vm_type = @deployment.vm_type(vm_type_name)

        if vm_type_name && vm_type.nil?
          raise InstanceGroupUnknownVmType,
                "Instance group '#{name}' references an unknown vm type '#{vm_type_name}'"
        end

        if vm_resources
          vm_resources = VmResources.new(vm_resources)
          @logger.debug("Using 'vm_resources' block for instance group '#{name}'")
        end

        [vm_resources, vm_type]
      end

      def parse_vm_extensions
        vm_extension_names = Array(safe_property(@instance_group_spec, 'vm_extensions', class: Array, optional: true))
        Array(vm_extension_names).map { |vm_extension_name| @deployment.vm_extension(vm_extension_name) }
      end

      def raise_vm_configuration_error(name, statement_count)
        case statement_count
        when 0
          raise InstanceGroupBadVmConfiguration,
                "Instance group '#{name}' is missing either 'vm_type' or 'vm_resources' section."
        else
          raise InstanceGroupBadVmConfiguration,
                "Instance group '#{name}' can only specify 'vm_type' or 'vm_resources' keys."
        end
      end

      def parse_update_config(options)
        parse_options = options.slice('canaries', 'max_in_flight')
        update_spec = safe_property(@instance_group_spec, 'update', class: Hash, optional: true)
        UpdateConfig.new((update_spec || {}).merge(parse_options), @deployment.update)
      end

      def parse_state(name)
        state = safe_property(@instance_group_spec, 'state', class: String, optional: true)
        if state && !InstanceGroup::VALID_STATES.include?(state)
          raise InstanceGroupInvalidState,
                "Invalid state '#{state}' for '#{name}', valid states are: #{InstanceGroup::VALID_STATES.join(', ')}"
        end

        state
      end

      def parse_desired_instances(name, networks)
        instances = safe_property(@instance_group_spec, 'instances', class: Integer)
        networks.each do |network|
          static_ips = network.static_ips
          next unless static_ips && static_ips.size != instances

          raise InstanceGroupNetworkInstanceIpMismatch,
                "Instance group '#{name}' has #{instances} instances but" \
                " was allocated #{static_ips.size} static IPs in network '#{network.name}'"
        end

        instances
      end

      def parse_instance_states(name)
        instance_states = safe_property(@instance_group_spec, 'instance_states', class: Hash, default: {})
        instance_states.each_pair do |index_or_id, state|
          next if InstanceGroup::VALID_STATES.include?(state)

          raise InstanceGroupInvalidInstanceState,
                "Invalid state '#{state}' for '#{name}/#{index_or_id}'," \
                " valid states are: #{InstanceGroup::VALID_STATES.join(', ')}"
        end

        instance_states
      end

      def parse_migrated_from(instance_group_name, availability_zones)
        migrated_from = safe_property(@instance_group_spec, 'migrated_from', class: Array, optional: true, default: [])

        migrated_from.map do |migrated_from_job_spec|
          name = safe_property(migrated_from_job_spec, 'name', class: String)
          az = safe_property(migrated_from_job_spec, 'az', class: String, optional: true)

          unless az.nil?
            unless availability_zones.to_a.map(&:name).include?(az)
              raise DeploymentInvalidMigratedFromJob,
                    "Instance group '#{name}' specified for migration to instance group '#{instance_group_name}'" \
                    " refers to availability zone '#{az}'. " \
                    "Az '#{az}' is not in the list of availability zones of instance group '#{instance_group_name}'."
            end
          end

          MigratedFromJob.new(name, az)
        end
      end

      def validate_instance_group(name)
        template_property = safe_property(@instance_group_spec, 'template', optional: true)
        templates_property = safe_property(@instance_group_spec, 'templates', optional: true)
        jobs_property = safe_property(@instance_group_spec, 'jobs', optional: true)

        if template_property || templates_property
          raise V1DeprecatedTemplate,
                "Instance group '#{name}' specifies template or templates. This is no longer supported, please use jobs instead"
        end

        raise ValidationMissingField, "Instance group '#{name}' does not specify jobs key" if jobs_property.nil?
      end

      def assign_default_networks(networks)
        default_networks = {}

        Network.valid_defaults.each do |property|
          network = networks.find { |network| network.default_for?(property) }
          default_networks[property] = network.name if network
        end

        default_networks
      end

      def parse_env
        env = Env.new(safe_property(@instance_group_spec, 'env', class: Hash, default: {}))

        if Config.remove_dev_tools
          env.spec['bosh'] ||= {}
          env.spec['bosh']['remove_dev_tools'] = Config.remove_dev_tools unless env.spec['bosh'].key?('remove_dev_tools')
        end

        update_tmpfs_properties(env, @deployment.use_tmpfs_config) unless @deployment.use_tmpfs_config.nil?

        env
      end

      def update_tmpfs_properties(env, value)
        env.spec['bosh'] ||= {}
        env.spec['bosh']['job_dir'] ||= {}
        env.spec['bosh']['job_dir']['tmpfs'] = value unless env.spec['bosh']['job_dir'].key?('tmpfs')

        env.spec['bosh']['agent'] ||= {}
        env.spec['bosh']['agent']['settings'] ||= {}
        env.spec['bosh']['agent']['settings']['tmpfs'] = value unless env.spec['bosh']['agent']['settings'].key?('tmpfs')
      end
    end
  end
end
