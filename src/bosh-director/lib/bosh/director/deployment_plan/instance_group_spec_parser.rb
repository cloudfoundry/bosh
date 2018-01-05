require 'bosh/template/property_helper'

module Bosh::Director
  module DeploymentPlan
    class InstanceGroupSpecParser
      include ValidationHelper
      include Bosh::Template::PropertyHelper
      include IpUtil

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      def initialize(deployment, event_log, logger)
        @deployment = deployment
        @event_log = event_log
        @logger = logger
        @links_manager = Bosh::Director::Links::LinksManager.new # TODO LINKS: Make this a passed in dependency of IGSP?
      end

      # @param [Hash] instance_group_spec Raw instance_group spec from the deployment manifest
      # @return [DeploymentPlan::InstanceGroup] Instance groups as built from instance_group_spec
      def parse(instance_group_spec, options = {})
        @instance_group_spec = instance_group_spec
        @instance_group = InstanceGroup.new(@logger)

        parse_name
        parse_lifecycle

        parse_release
        validate_jobs

        merged_global_and_instance_group_properties = extract_global_and_instance_group_properties

        parse_legacy_template(merged_global_and_instance_group_properties)
        parse_jobs(merged_global_and_instance_group_properties)

        check_job_uniqueness
        parse_disks

        parse_resource_pool
        check_remove_dev_tools

        parse_options = {}
        parse_options['canaries'] = options['canaries'] if options['canaries']
        parse_options['max_in_flight'] = options['max_in_flight'] if options['max_in_flight']
        parse_update_config(parse_options)

        networks = InstanceGroupNetworksParser.new(Network::REQUIRED_DEFAULTS, Network::OPTIONAL_DEFAULTS).parse(@instance_group_spec, @instance_group.name, @deployment.networks)
        @instance_group.networks = networks
        assign_default_networks(networks)

        availability_zones = InstanceGroupAvailabilityZoneParser.new.parse(@instance_group_spec, @instance_group, @deployment, networks)
        @instance_group.availability_zones = availability_zones

        parse_migrated_from

        desired_instances = parse_desired_instances(availability_zones, networks)
        @instance_group.desired_instances = desired_instances

        @instance_group.deployment_name = @deployment.name

        @instance_group
      end

      private

      def parse_name
        @instance_group.name = safe_property(@instance_group_spec, "name", :class => String)
        @instance_group.canonical_name = Canonicalizer.canonicalize(@instance_group.name)
      end

      def parse_lifecycle
        lifecycle = safe_property(@instance_group_spec, "lifecycle",
          :class => String,
          :optional => true,
          :default => InstanceGroup::DEFAULT_LIFECYCLE_PROFILE,
        )

        unless InstanceGroup::VALID_LIFECYCLE_PROFILES.include?(lifecycle)
          raise JobInvalidLifecycle,
            "Invalid lifecycle '#{lifecycle}' for '#{@instance_group.name}', " +
            "valid lifecycle profiles are: #{InstanceGroup::VALID_LIFECYCLE_PROFILES.join(', ')}"
        end

        @instance_group.lifecycle = lifecycle
      end

      def parse_release
        release_name = safe_property(@instance_group_spec, "release", :class => String, :optional => true)

        if release_name.nil?
          if @deployment.releases.size == 1
            @instance_group.release = @deployment.releases.first
          end
        else
          @instance_group.release = @deployment.release(release_name)

          if @instance_group.release.nil?
            raise InstanceGroupUnknownRelease,
                  "Instance group '#{@instance_group.name}' references an unknown release '#{release_name}'"
          end
        end
      end

      # legacy template parsing
      def parse_legacy_template(merged_global_and_instance_group_properties)
        job_names = safe_property(@instance_group_spec, 'template', optional: true)
        if job_names
          if job_names.is_a?(Array)
            @event_log.warn_deprecated(
              "Please use 'templates' when specifying multiple templates for a job. " +
              "'template' for multiple templates will soon be unsupported."
            )
          end

          unless job_names.is_a?(Array) || job_names.is_a?(String)
            invalid_type("template", "String or Array", job_names)
          end

          unless @instance_group.release
            raise InstanceGroupMissingRelease, "Cannot tell what release job '#{@instance_group.name}' is supposed to use, please explicitly specify one"
          end

          Array(job_names).each do |job_name|
            current_job = @instance_group.release.get_or_create_template(job_name)
            current_job.add_properties(
              merged_global_and_instance_group_properties,
              @instance_group.name
            )
            @instance_group.jobs << current_job
          end
        end
      end

      def parse_jobs(merged_global_and_instance_group_properties)
        legacy_jobs = safe_property(@instance_group_spec, 'templates', class: Array, optional: true)
        jobs = safe_property(@instance_group_spec, 'jobs', class: Array, optional: true)

        if jobs.nil?
          jobs = legacy_jobs
        end

        if jobs
          release_manager = Api::ReleaseManager.new

          # Key: release name.
          # Value: list of templates models of release version.
          release_versions_templates_models_hash = {}

          jobs.each do |job_spec|
            job_name = safe_property(job_spec, 'name', class: String)
            release_name = safe_property(job_spec, 'release', class: String, optional: true)

            if release_name
              release = @deployment.release(release_name)
              unless release
                raise InstanceGroupUnknownRelease,
                      "Job '#{job_name}' (instance group '#{@instance_group.name}') references an unknown release '#{release_name}'"
              end
            else
              release = @instance_group.release
              unless release
                raise InstanceGroupMissingRelease, "Cannot tell what release template '#{job_name}' (instance group '#{@instance_group.name}') is supposed to use, please explicitly specify one"
              end
              release_name = release.name
            end

            unless release_versions_templates_models_hash.has_key?(release_name)
              release_model = release_manager.find_by_name(release.name)
              current_release_version = release_manager.find_version(release_model, release.version)
              release_versions_templates_models_hash[release_name] = current_release_version.templates
            end

            templates_models_list = release_versions_templates_models_hash[release_name]
            current_template_model = templates_models_list.find {|target| target.name == job_name }

            job = release.get_or_create_template(job_name)

            if current_template_model == nil
              raise "Job '#{job_name}' not found in Template table"
            end

            if job_spec.has_key?('properties')
              job_properties = safe_property(job_spec, 'properties', class: Hash, optional: true, default: {})
            else
              job_properties = merged_global_and_instance_group_properties
            end

            job.add_properties(
              job_properties,
              @instance_group.name
            )

            # Find out what is the exported properties per job, store them somewhere? DB?
            # add_link_from_release parses out which properties to be exported.
            # The values of each property to be exported should be the ones passed to 'job.add_properties'
            provider = nil

            # Providers defined from manifest
            provides_links = safe_property(job_spec, 'provides', class: Hash, optional: true, default: {})

            if current_template_model.provides != nil
              provider = @links_manager.find_or_create_provider(
                deployment_model: @deployment.model,
                instance_group_name: @instance_group.name,
                name: job_name,
                type: 'job'
              )

              errors = []

              current_template_model.provides.each do |provides|
                link_name = provides['name']
                provider_intent = @links_manager.find_or_create_provider_intent(
                  link_provider: provider,
                  link_original_name: link_name,
                  link_type: provides['type']
                )

                exported_properties = provides['properties'] || []

                manifest_source = provides_links[link_name]
                if manifest_source # This provider is defined in my manifest
                  errors.concat(validate_link_def(link_name, provider_intent, manifest_source, job_name))

                  if manifest_source.eql? 'nil' # User explicitly specified nil. eg. "---\nfoo: nil\n"
                    provider_intent.consumable = false
                  else
                    provider_intent.name = manifest_source['as'] || link_name
                    provider_intent.shared = manifest_source['shared'] || false
                  end

                  mapped_properties = process_link_properties(job_properties, get_default_properties(@deployment, job), exported_properties, errors)

                  provider_intent.metadata = {:mapped_properties => mapped_properties}.to_json
                  provider_intent.save
                  provides_links.delete(link_name)
                end
              end

              errors.push('....') unless provides_links.empty?

              unless errors.empty?
                raise errors.join("\n")
              end
            end
            raise "Job '#{job_name}' does not define any providers in the release spec" if provider.nil? && !provides_links.empty?

            consumer = nil
            if current_template_model.consumes != nil
              consumer = @links_manager.find_or_create_consumer(
                deployment_model: @deployment.model,
                instance_group_name: @instance_group.name,
                name: job_name,
                type: 'job'
              )
              current_template_model.consumes.each do |consumes|
                @links_manager.find_or_create_consumer_intent(
                  link_consumer: consumer,
                  link_original_name: consumes["name"],
                  link_type: consumes['type']
                )
              end
            end

            consumes_links = safe_property(job_spec, 'consumes', class: Hash, optional: true) || {}
            raise "Job '#{job_name}' does not define any consumers in the release spec" if consumer.nil? && !consumes_links.empty?

            consumes_links.each do |link_name, source|
              consumer_intent = consumer.intents&.find do |intent|
                intent.original_name == link_name
              end

              errors = validate_consume_link(source, link_name, @instance_group.name)
              errors.concat(validate_link_def(link_name, consumer_intent, source, job_name))

              if errors.size > 0
                raise errors.join("\n")
              end

              if source.eql? 'nil' # User explicitly specified nil. eg. "---\nfoo: nil\n"
                consumer_intent.blocked = true
              else
                consumer_intent.name = source['from']
                consumer_intent.optional = source['optional'] || false

                metadata = {}
                metadata['ip_addresses'] = source['ip_addresses'] if source.has_key? ('ip_addresses')
                metadata['network'] = source['network'] if source.has_key? ('network')
                if source['deployment']
                  from_deployment = Bosh::Director::Models::Deployment.find(name: source['deployment'])
                  if from_deployment
                    metadata['from_deployment'] = from_deployment
                  else
                    errors.push("Deployment #{source['deployment']} not found for consumed link #{consumer_intent.name}")
                  end
                end
                consumer_intent.metadata = metadata.to_json
              end
              consumer_intent.save

              manual_link_keys = [ 'instances', 'properties', 'address' ]
              is_manual_link = manual_link_keys.any? do |key|
                source.has_key? key
              end
              process_manual_link(consumer, intent, source, manual_link_keys) if is_manual_link
            end

            @instance_group.jobs << job
          end
        end
      end

      def process_manual_link(consumer, consumer_intent, source, manual_link_property_keys)
        manual_provider = @links_manager.find_or_create_provider(
          deployment_model: consumer.deployment,
          instance_group_name: consumer.instance_group,
          name: consumer.name,
          type: 'manual'
        )

        manual_provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: manual_provider,
          link_original_name: consumer_intent.name,
          link_type: consumer_intent.type
        )

        content = {
          'deployment_name' => consumer.deployment.name
        }
        #TODO LINKS: Maybe only take certain manual link properties like link_path.parse used to:
        #   @manual_spec = {}
        #   @manual_spec['deployment_name'] = @deployment_plan_name
        #   @manual_spec['instances'] = link_info['instances']
        #   @manual_spec['properties'] = link_info['properties']
        #   @manual_spec['address'] = link_info['address']
        manual_link_property_keys.each do |key|
          content[key] = source[key]
        end
        manual_provider_intent.content = content.to_json
        manual_provider_intent.save
      end

      def validate_link_def(link_name, link_intent, source, job_name)
        errors = []

        errors.push("Job '#{job_name}' does not define link '#{link_name}' in the release spec") unless link_intent
        unless source.nil? # User did not define any source definition, only the link name. eg. "---\nfoo:\n"
          if source.has_key?('name') || source.has_key?('type')
            errors.push("Cannot specify 'name' or 'type' properties in the manifest for link '#{link_name}' in job '#{@name}' in instance group '#{@instance_group.name}'. Please provide these keys in the release only.")
          end
        end

        errors
      end

      def validate_consume_link(source, link_name, instance_group_name)
        errors = []
        if source == nil
          return errors
        end

        blacklist = [['instances', 'from'], ['properties', 'from']]
        blacklist.each do |invalid_props|
          if invalid_props.all? {|prop| source.has_key?(prop)}
            errors.push("Cannot specify both '#{invalid_props[0]}' and '#{invalid_props[1]}' keys for link '#{link_name}' in job '#{@name}' in instance group '#{instance_group_name}'.")
          end
        end

        if source.has_key?('properties') && !source.has_key?('instances')
          errors.push("Cannot specify 'properties' without 'instances' for link '#{link_name}' in job '#{@name}' in instance group '#{instance_group_name}'.")
        end

        if source.has_key?('ip_addresses')
          # The first expression makes it TRUE or FALSE then if the second expression is neither TRUE or FALSE it will return FALSE
          unless (!!source['ip_addresses']) == source['ip_addresses']
            errors.push("Cannot specify non boolean values for 'ip_addresses' field for link '#{link_name}' in job '#{@name}' in instance group '#{instance_group_name}'.")
          end
        end

        errors
      end

      def check_job_uniqueness
        all_names = @instance_group.jobs.map(&:name)
        @instance_group.jobs.each do |job|
          if all_names.count(job.name) > 1
            raise InstanceGroupInvalidTemplates,
                  "Colocated job '#{job.name}' is already added to the instance group '#{@instance_group.name}'"
          end
        end
      end

      def parse_disks
        disk_size = safe_property(@instance_group_spec, 'persistent_disk', :class => Integer, :optional => true)
        disk_type_name = safe_property(@instance_group_spec, 'persistent_disk_type', :class => String, :optional => true)
        disk_pool_name = safe_property(@instance_group_spec, 'persistent_disk_pool', :class => String, :optional => true)
        persistent_disks = safe_property(@instance_group_spec, 'persistent_disks', :class => Array, :optional => true)

        if [disk_size, disk_type_name, disk_pool_name, persistent_disks].compact!.size > 1
          raise InstanceGroupInvalidPersistentDisk,
            "Instance group '#{@instance_group.name}' specifies more than one of the following keys:" +
              " 'persistent_disk', 'persistent_disk_type', 'persistent_disk_pool' and 'persistent_disks'. Choose one."
        end

        if disk_type_name
          disk_name = disk_type_name
          disk_source = 'type'
        else
          disk_name = disk_pool_name
          disk_source = 'pool'
        end

        persistent_disk_collection = PersistentDiskCollection.new(@logger)

        if disk_size
          if disk_size < 0
            raise InstanceGroupInvalidPersistentDisk,
              "Instance group '#{@instance_group.name}' references an invalid persistent disk size '#{disk_size}'"
          end

          persistent_disk_collection.add_by_disk_size(disk_size) unless disk_size == 0
        end

        if disk_name
          disk_type = @deployment.disk_type(disk_name)
          if disk_type.nil?
            raise InstanceGroupUnknownDiskType,
              "Instance group '#{@instance_group.name}' references an unknown disk #{disk_source} '#{disk_name}'"
          end

          persistent_disk_collection.add_by_disk_type(disk_type)
        end

        # TODO LINKS: Add disks to the provider + intents
        # The disks being added should have alias set to the original name
        if persistent_disks
          unique_names = persistent_disks.map { |persistent_disk| persistent_disk['name'] }.uniq
          if unique_names.size != persistent_disks.size
            raise InstanceGroupInvalidPersistentDisk,
              "Instance group '#{@instance_group.name}' persistent_disks's section contains duplicate names"
          end

          persistent_disks.each do |persistent_disk|
            disk_type_name = persistent_disk['type']
            disk_type = @deployment.disk_type(disk_type_name)
            if disk_type.nil?
              raise InstanceGroupUnknownDiskType,
                "Instance group '#{@instance_group.name}' persistent_disks's section references an unknown disk type '#{disk_type_name}'"
            end

            persistent_disk_name = persistent_disk['name']
            if persistent_disk_name.blank?
              raise InstanceGroupInvalidPersistentDisk,
                "Instance group '#{@instance_group.name}' persistent_disks's section contains a disk with no name"
            end

            persistent_disk_collection.add_by_disk_name_and_type(persistent_disk_name, disk_type)
          end
        end

        @instance_group.persistent_disk_collection = persistent_disk_collection
      end

      def extract_global_and_instance_group_properties
        # Manifest can contain global and per-instance_group properties section
        instance_group_properties = safe_property(@instance_group_spec, 'properties', :class => Hash, :optional => true, :default => {})

        merged_properties = @deployment.properties.recursive_merge(instance_group_properties)

        mappings = safe_property(@instance_group_spec, 'property_mappings', :class => Hash, :default => {})

        mappings.each_pair do |to, from|
          resolved = lookup_property(merged_properties, from)

          if resolved.nil?
            raise InstanceGroupInvalidPropertyMapping,
                  "Cannot satisfy property mapping '#{to}: #{from}', as '#{from}' is not in deployment properties"
          end

          merged_properties[to] = resolved
        end
        merged_properties
      end

      def parse_resource_pool
        env_hash = safe_property(@instance_group_spec, 'env', class: Hash, :default => {})

        resource_pool_name = safe_property(@instance_group_spec, "resource_pool", class: String, optional: true)

        if resource_pool_name
          resource_pool = @deployment.resource_pool(resource_pool_name)
          if resource_pool.nil?
            raise InstanceGroupUnknownResourcePool,
              "Instance group '#{@instance_group.name}' references an unknown resource pool '#{resource_pool_name}'"
          end

          vm_type = VmType.new({
            'name' => resource_pool.name,
            'cloud_properties' => resource_pool.cloud_properties
          })

          vm_resources = nil
          vm_extensions = []

          stemcell = resource_pool.stemcell

          if !env_hash.empty? && !resource_pool.env.empty?
            raise InstanceGroupAmbiguousEnv,
              "Instance group '#{@instance_group.name}' and resource pool: '#{resource_pool_name}' both declare env properties"
          end

          if env_hash.empty?
            env_hash = resource_pool.env
          end
        else
          vm_type_name = safe_property(@instance_group_spec, 'vm_type', class: String, optional: true)
          vm_resources = safe_property(@instance_group_spec, 'vm_resources', class: Hash, optional: true)
          vm_type = nil
          if vm_type_name && vm_resources
            raise InstanceGroupBadVmConfiguration, "Instance group '#{@instance_group.name}' specifies both 'vm_type' and 'vm_resources' keys, only one is allowed."
          elsif vm_type_name
            vm_type = @deployment.vm_type(vm_type_name)
            raise InstanceGroupUnknownVmType, "Instance group '#{@instance_group.name}' references an unknown vm type '#{vm_type_name}'" unless vm_type
          elsif vm_resources
            vm_resources = VmResources.new(vm_resources)
            @logger.debug("Using 'vm_resources' block for instance group '#{@instance_group.name}'")
          else
            raise InstanceGroupBadVmConfiguration, "Instance group '#{@instance_group.name}' is missing either 'vm_type' or 'vm_resources' or 'resource_pool' section."
          end

          vm_extension_names = Array(safe_property(@instance_group_spec, 'vm_extensions', class: Array, optional: true))
          vm_extensions = Array(vm_extension_names).map {|vm_extension_name| @deployment.vm_extension(vm_extension_name)}

          stemcell_name = safe_property(@instance_group_spec, 'stemcell', class: String)
          stemcell = @deployment.stemcell(stemcell_name)
          if stemcell.nil?
            raise InstanceGroupUnknownStemcell,
              "Instance group '#{@instance_group.name}' references an unknown stemcell '#{stemcell_name}'"
          end
        end

        @instance_group.vm_resources = vm_resources
        @instance_group.vm_type = vm_type
        @instance_group.vm_extensions = vm_extensions
        @instance_group.stemcell = stemcell
        @instance_group.env = Env.new(env_hash)
      end

      def parse_update_config(parse_options)
        update_spec = safe_property(@instance_group_spec, "update", class: Hash, optional: true)
        @instance_group.update = UpdateConfig.new((update_spec || {}).merge(parse_options), @deployment.update)
      end

      def parse_desired_instances(availability_zones, networks)
        @instance_group.state = safe_property(@instance_group_spec, "state", class: String, optional: true)
        instances = safe_property(@instance_group_spec, "instances", class: Integer)
        instance_states = safe_property(@instance_group_spec, "instance_states", class: Hash, default: {})

        networks.each do |network|
          static_ips = network.static_ips
          if static_ips && static_ips.size != instances
            raise InstanceGroupNetworkInstanceIpMismatch,
              "Instance group '#{@instance_group.name}' has #{instances} instances but was allocated #{static_ips.size} static IPs in network '#{network.name}'"
          end
        end

        instance_states.each_pair do |index_or_id, state|
          unless InstanceGroup::VALID_STATES.include?(state)
            raise InstanceGroupInvalidInstanceState,
              "Invalid state '#{state}' for '#{@instance_group.name}/#{index_or_id}', valid states are: #{InstanceGroup::VALID_STATES.join(", ")}"
          end

          @instance_group.instance_states[index_or_id] = state
        end

        if @instance_group.state && !InstanceGroup::VALID_STATES.include?(@instance_group.state)
          raise InstanceGroupInvalidState,
            "Invalid state '#{@instance_group.state}' for '#{@instance_group.name}', valid states are: #{InstanceGroup::VALID_STATES.join(", ")}"
        end

        instances.times.map { DesiredInstance.new(@instance_group, @deployment) }
      end

      def parse_migrated_from
        migrated_from = safe_property(@instance_group_spec, 'migrated_from', class: Array, optional: true, :default => [])
        migrated_from.each do |migrated_from_job_spec|
          name = safe_property(migrated_from_job_spec, 'name', class: String)
          az = safe_property(migrated_from_job_spec, 'az', class: String, optional: true)
          unless az.nil?
            unless @instance_group.availability_zones.to_a.map(&:name).include?(az)
              raise DeploymentInvalidMigratedFromJob,
              "Instance group '#{name}' specified for migration to instance group '#{@instance_group.name}' refers to availability zone '#{az}'. " +
                "Az '#{az}' is not in the list of availability zones of instance group '#{@instance_group.name}'."
            end
          end
          @instance_group.migrated_from << MigratedFromJob.new(name, az)
        end
      end

      def process_links(deployment)
        errors = []

        @instance_group.jobs.each do |current_job|
          # current_job.consumes_links_for_instance_group_name(@instance_group.name).each do |name, source|
          #   link_path = LinkPath.new(deployment.name, deployment.instance_groups, @instance_group.name, current_job.name)
          #
          #   begin
          #     link_path.parse(source)
          #   rescue Exception => e
          #     errors.push e
          #   end
          #
          #   unless link_path.skip
          #     @instance_group.add_link_path(current_job.name, name, link_path)
          #   end
          # end

          template_properties = current_job.properties[@instance_group.name]

          current_job.provides_links_for_instance_group_name(@instance_group.name).each do |_link_name, provided_link|
            next unless provided_link['link_properties_exported']
            ## Get default values for this job
            default_properties = get_default_properties(deployment, current_job)

            provided_link['mapped_properties'] = process_link_properties(template_properties, default_properties, provided_link['link_properties_exported'], errors)
          end
        end

        unless errors.empty?
          combined_errors = errors.map { |error| "- #{error.message.strip}" }.join("\n")
          header = 'Unable to process links for deployment. Errors are:'
          message = Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, combined_errors.strip, indent_by: 2)

          raise message
        end
      end

      def get_default_properties(deployment, template)
        release_manager = Api::ReleaseManager.new

        release_versions_templates_models_hash = {}

        template_name = template.name
        release_name = template.release.name

        release = deployment.release(release_name)

        unless release_versions_templates_models_hash.key?(release_name)
          release_model = release_manager.find_by_name(release_name)
          current_release_version = release_manager.find_version(release_model, release.version)
          release_versions_templates_models_hash[release_name] = current_release_version.templates
        end

        templates_models_list = release_versions_templates_models_hash[release_name]
        current_template_model = templates_models_list.find { |target| target.name == template_name }

        unless current_template_model.properties.nil?
          default_prop = {}
          default_prop['properties'] = current_template_model.properties
          default_prop['template_name'] = template.name
          return default_prop
        end

        { 'template_name' => template.name }
      end

      def process_link_properties(scoped_properties, default_properties, link_property_list, errors)
        mapped_properties = {}
        link_property_list.each do |link_property|
          property_path = link_property.split('.')
          result = find_property(property_path, scoped_properties)
          if !result['found']
            if default_properties.key?('properties') && default_properties['properties'].key?(link_property)
              if default_properties['properties'][link_property].key?('default')
                mapped_properties = update_mapped_properties(mapped_properties, property_path, default_properties['properties'][link_property]['default'])
              else
                mapped_properties = update_mapped_properties(mapped_properties, property_path, nil)
              end
            else
              e = Exception.new("Link property #{link_property} in template #{default_properties['template_name']} is not defined in release spec")
              errors.push(e)
            end
          else
            mapped_properties = update_mapped_properties(mapped_properties, property_path, result['value'])
          end
        end
        mapped_properties
      end

      def find_property(property_path, scoped_properties)
        current_node = scoped_properties
        property_path.each do |key|
          if !current_node || !current_node.key?(key)
            return { 'found' => false, 'value' => nil }
          else
            current_node = current_node[key]
          end
        end
        { 'found' => true, 'value' => current_node }
      end

      def update_mapped_properties(mapped_properties, property_path, value)
        current_node = mapped_properties
        property_path.each_with_index do |key, index|
          if index == property_path.size - 1
            current_node[key] = value
          else
            current_node[key] = {} unless current_node.key?(key)
            current_node = current_node[key]
          end
        end
        mapped_properties
      end

      def validate_jobs
        template_property = safe_property(@instance_group_spec, 'template', optional: true)
        templates_property = safe_property(@instance_group_spec, 'templates', optional: true)
        jobs_property = safe_property(@instance_group_spec, 'jobs', optional: true)

        if template_property && templates_property
          raise InstanceGroupInvalidTemplates, "Instance group '#{@instance_group.name}' specifies both template and templates keys, only one is allowed"
        end

        if templates_property && jobs_property
          raise InstanceGroupInvalidTemplates, "Instance group '#{@instance_group.name}' specifies both templates and jobs keys, only one is allowed"
        end

        if template_property && jobs_property
          raise InstanceGroupInvalidTemplates, "Instance group '#{@instance_group.name}' specifies both template and jobs keys, only one is allowed"
        end

        if [template_property, templates_property, jobs_property].compact.empty?
          raise ValidationMissingField,
                "Instance group '#{@instance_group.name}' does not specify jobs key"
        end
      end

      def assign_default_networks(networks)
        Network.valid_defaults.each do |property|
          network = networks.find { |network| network.default_for?(property) }
          @instance_group.default_network[property] = network.name if network
        end
      end

      def check_remove_dev_tools
        if Config.remove_dev_tools
          @instance_group.env.spec['bosh'] ||= {}
          unless @instance_group.env.spec['bosh'].has_key?('remove_dev_tools')
            @instance_group.env.spec['bosh']['remove_dev_tools'] = Config.remove_dev_tools
          end
        end
      end
    end
  end
end
