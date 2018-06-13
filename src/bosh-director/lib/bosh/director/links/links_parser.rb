module Bosh::Director::Links
  class LinksParser
    include Bosh::Director::ValidationHelper

    MANUAL_LINK_KEYS = %w[instances properties address].freeze

    class LinkProvidersParser
      include Bosh::Director::ValidationHelper
      def initialize
        @logger = Bosh::Director::Config.logger
        @link_helper = LinkHelpers.new
      end

      def parse_migrated_from_providers_from_job(
        manifest_job_spec, deployment_model, current_template_model, manifest_details = {}
      )
        job_properties = manifest_details.fetch(:job_properties, {})
        instance_group_name = manifest_details.fetch(:instance_group_name, nil)
        migrated_from = manifest_details.fetch(:migrated_from, [])

        migrated_from.each do |migration_block|
          # old_instance_group_name = migration_block['name']
          job_name = safe_property(manifest_job_spec, 'name', class: String)

          providers = Bosh::Director::Models::Links::LinkProvider.find(
            deployment: deployment_model,
            instance_group: migration_block['name'],
            name: job_name,
            type: 'job',
          )

          instance_group_name = migration_block['name'] unless providers.nil?
        end

        parse_providers_from_job(
          manifest_job_spec,
          deployment_model,
          current_template_model,
          job_properties: job_properties,
          instance_group_name: instance_group_name,
        )
      end

      def parse_providers_from_job(manifest_job_spec, deployment_model, current_release_template_model, manifest_details = {})
        job_properties = manifest_details.fetch(:job_properties, {})
        instance_group_name = manifest_details.fetch(:instance_group_name, nil)
        @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

        manifest_provides_links = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'provides',
                                                                            class: Hash, optional: true, default: {}))
        custom_manifest_providers = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'custom_provider_definitions',
                                                                              class: Array, optional: true, default: []))
        job_name = safe_property(manifest_job_spec, 'name', class: String)

        @link_helper.validate_custom_providers(custom_manifest_providers, current_release_template_model.provides, job_name,
                                               instance_group_name, current_release_template_model.release.name)

        errors = []

        errors.concat(
          process_custom_providers(
            current_release_template_model,
            custom_manifest_providers,
            manifest_provides_links,
            deployment_model,
            job_properties: job_properties,
            instance_group_name: instance_group_name,
          ),
        )
        errors.concat(process_release_providers(current_release_template_model, manifest_provides_links, deployment_model,
                                                instance_group_name, job_properties))

        unless manifest_provides_links.empty?
          warning = 'Manifest defines unknown providers:'
          manifest_provides_links.each_key do |link_name|
            warning << "\n  - Job '#{job_name}' does not define link provider '#{link_name}' in the release spec"
          end
          @logger.warn(warning)
        end

        raise errors.join("\n") unless errors.empty?
      end

      def parse_provider_from_disk(disk_spec, deployment_model, instance_group_name)
        @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

        disk_name = disk_spec['name'] # All the parsing we need

        provider = @links_manager.find_or_create_provider(
          deployment_model: deployment_model,
          instance_group_name: instance_group_name,
          name: instance_group_name,
          type: 'disk',
        )

        create_disk_provider_intent(deployment_model, disk_name, provider)
      end

      private

      def create_disk_provider_intent(deployment_model, disk_name, provider)
        provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: provider,
          link_original_name: disk_name,
          link_type: 'disk',
        )

        provider_intent.shared = false
        provider_intent.name = disk_name
        provider_intent.content = Bosh::Director::DeploymentPlan::DiskLink.new(deployment_model.name, disk_name).spec.to_json
        provider_intent.save
      end

      def process_providers(release_properties, provider_definitions, manifest_provides_links, deployment_model, job_details = {})
        job_properties = job_details.fetch(:job_properties, {})
        instance_group_name = job_details.fetch(:instance_group_name, nil)
        job_name = job_details.fetch(:job_name, nil)
        are_custom_definitions = job_details.fetch(:are_custom_definitions, false)

        provider = @links_manager.find_or_create_provider(
          deployment_model: deployment_model,
          instance_group_name: instance_group_name,
          name: job_name,
          type: 'job',
        )

        errors = process_provider_definitions(
          manifest_provides_links,
          provider,
          provider_definitions,
          release_properties,
          are_custom_definitions: are_custom_definitions,
          instance_group_name: instance_group_name,
          job_name: job_name,
          job_properties: job_properties,
        )
        errors
      end

      def process_provider_definitions(
        manifest_provides_links,
        provider,
        provider_definitions,
        release_properties,
        manifest_details = {}
      )
        are_custom_definitions, instance_group_name, job_name, job_properties =
          @link_helper.extract_provider_definition_properties(manifest_details)
        errors = []

        provider_definitions.each do |provider_definition|
          provider_intent_params = {
            original_name: provider_definition['name'],
            type: provider_definition['type'],
            alias: provider_definition['name'],
            shared: false,
            consumable: true,
          }

          if manifest_provides_links.key?(provider_definition['name'])
            manifest_source = manifest_provides_links.delete(provider_definition['name'])

            validation_errors = @link_helper.validate_provide_link(
              manifest_source, provider_definition['name'], job_name, instance_group_name
            )
            errors.concat(validation_errors)
            next unless validation_errors.empty?

            provider_intent_params = @link_helper.generate_provider_intent_params(manifest_source, provider_intent_params)
          end

          mapped_properties, properties_errors = @link_helper.process_link_properties(
            job_properties, provider_definition['properties'], release_properties, job_name
          )
          errors.concat(properties_errors)

          next unless properties_errors.empty?

          create_provider_intent(are_custom_definitions, mapped_properties, provider, provider_intent_params)
        end
        errors
      end

      def create_provider_intent(are_custom_definitions, mapped_properties, provider, provider_intent_params)
        provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: provider,
          link_original_name: provider_intent_params[:original_name],
          link_type: provider_intent_params[:type],
        )

        provider_intent.name = provider_intent_params[:alias]
        provider_intent.shared = provider_intent_params[:shared]
        is_custom = are_custom_definitions || false
        provider_intent.metadata = { mapped_properties: mapped_properties, custom: is_custom }.to_json
        provider_intent.consumable = provider_intent_params[:consumable]
        provider_intent.save
      end

      def process_custom_providers(
        current_release_template_model,
        custom_manifest_providers,
        manifest_provides_links,
        deployment_model,
        manifest_details = {}
      )
        job_properties = manifest_details.fetch(:job_properties, {})
        instance_group_name = manifest_details.fetch(:instance_group_name, nil)
        return [] if custom_manifest_providers.empty?

        process_providers(
          current_release_template_model.properties,
          custom_manifest_providers,
          manifest_provides_links,
          deployment_model,
          job_properties: job_properties,
          instance_group_name: instance_group_name,
          job_name: current_release_template_model.name,
          are_custom_definitions: true,
        )
      end

      def process_release_providers(
        current_release_template_model,
        manifest_provides_links,
        deployment_model,
        instance_group_name,
        job_properties
      )
        job_name = current_release_template_model.name

        return [] if current_release_template_model.provides.empty?

        process_providers(
          current_release_template_model.properties,
          current_release_template_model.provides,
          manifest_provides_links,
          deployment_model,
          job_properties: job_properties,
          instance_group_name: instance_group_name,
          job_name: job_name,
          are_custom_definitions: false,
        )
      end
    end

    class LinkConsumersParser
      include Bosh::Director::ValidationHelper
      def initialize
        @logger = Bosh::Director::Config.logger
        @link_helper = LinkHelpers.new
      end

      def parse_migrated_from_consumers_from_job(
        manifest_job_spec, deployment_model, current_release_template_model, instance_group_details = {}
      )
        instance_group_name = instance_group_details.fetch(:instance_group_name, nil)
        migrated_from = instance_group_details.fetch(:migrated_from, [])
        migrated_from.each do |migration_block|
          old_instance_group_name = migration_block['name']
          job_name = safe_property(manifest_job_spec, 'name', class: String)

          consumers = Bosh::Director::Models::Links::LinkConsumer.find(
            deployment: deployment_model,
            instance_group: old_instance_group_name,
            name: job_name,
            type: 'job',
          )

          instance_group_name = migration_block['name'] unless consumers.nil?
        end

        parse_consumers_from_job(
          manifest_job_spec,
          deployment_model,
          current_release_template_model,
          instance_group_name: instance_group_name,
        )
      end

      def parse_consumers_from_job(
        manifest_job_spec, deployment_model, current_release_template_model, instance_group_details = {}
      )
        instance_group_name = instance_group_details.fetch(:instance_group_name, nil)
        @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

        consumes_links = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'consumes',
                                                                   class: Hash, optional: true, default: {}))
        job_name = safe_property(manifest_job_spec, 'name', class: String)

        errors = []
        unless current_release_template_model.consumes.empty?
          errors.concat(
            process_release_template_consumes(
              consumes_links,
              current_release_template_model,
              deployment_model,
              instance_group_name,
              job_name,
            ),
          )
        end

        unless consumes_links.empty?
          warning = 'Manifest defines unknown consumers:'
          consumes_links.each_key do |link_name|
            warning << "\n  - Job '#{job_name}' does not define link consumer '#{link_name}' in the release spec"
          end
          @logger.warn(warning)
        end

        raise errors.join("\n") unless errors.empty?
      end

      private

      def process_release_template_consumes(
        consumes_links, current_release_template_model, deployment_model, instance_group_name, job_name
      )
        consumer = @links_manager.find_or_create_consumer(
          deployment_model: deployment_model,
          instance_group_name: instance_group_name,
          name: job_name,
          type: 'job',
        )

        errors = create_consumer_intent_from_template_model(
          consumer, consumes_links, current_release_template_model, instance_group_name, job_name
        )
        errors
      end

      def create_consumer_intent_from_template_model(
        consumer, consumes_links, current_release_template_model, instance_group_name, job_name
      )
        errors = []
        current_release_template_model.consumes.each do |consumes|
          metadata = {}
          consumer_intent_params = {
            original_name: consumes['name'],
            alias: consumes['name'],
            blocked: false,
            type: consumes['type'],
          }

          if !consumes_links.key?(consumes['name'])
            metadata[:explicit_link] = false
          else
            consumer_intent_params, metadata, err = generate_explicit_link_metadata(
              consumer,
              consumer_intent_params,
              consumes_links,
              metadata,
              consumed_link_original_name: consumes['name'],
              job_name: job_name,
              instance_group_name: instance_group_name,
            )
            unless err.empty?
              errors.concat(err)
              next
            end
          end

          create_consumer_intent(consumer, consumer_intent_params, consumes, metadata)
        end
        errors
      end

      def generate_explicit_link_metadata(
        consumer, consumer_intent_params, consumes_links, metadata, names = {}
      )
        consumed_link_original_name = names.fetch(:consumed_link_original_name, nil)
        job_name = names.fetch(:job_name, nil)
        instance_group_name = names.fetch(:instance_group_name, nil)

        errors = []
        manifest_source = consumes_links.delete(consumed_link_original_name)

        new_errors = @link_helper.validate_consume_link(
          manifest_source, consumed_link_original_name, job_name, instance_group_name
        )
        errors.concat(new_errors)
        return consumer_intent_params, metadata, errors unless new_errors.empty?

        metadata[:explicit_link] = true

        if manifest_source.eql? 'nil'
          consumer_intent_params[:blocked] = true
        elsif @link_helper.manual_link? manifest_source
          metadata[:manual_link] = true
          process_manual_link(consumer, consumer_intent_params, manifest_source)
        else
          consumer_intent_params[:alias] = manifest_source.fetch('from', consumer_intent_params[:alias])
          metadata[:ip_addresses] = manifest_source['ip_addresses'] if manifest_source.key?('ip_addresses')
          metadata[:network] = manifest_source['network'] if manifest_source.key?('network')
          validate_consumes_deployment(
            consumer_intent_params,
            errors,
            manifest_source,
            metadata,
            instance_group_name: instance_group_name,
            job_name: job_name,
          )
        end
        [consumer_intent_params, metadata, errors]
      end

      def validate_consumes_deployment(consumer_intent_params, errors, manifest_source, metadata, instance_group_details = {})
        return unless manifest_source['deployment']
        instance_group_name = instance_group_details.fetch(:instance_group_name, nil)
        job_name = instance_group_details.fetch(:job_name, nil)

        from_deployment = Bosh::Director::Models::Deployment.find(name: manifest_source['deployment'])
        metadata[:from_deployment] = manifest_source['deployment']

        from_deployment_error_message = "Link '#{consumer_intent_params[:alias]}' in job '#{job_name}' from instance group"\
                  " '#{instance_group_name}' consumes from deployment '#{manifest_source['deployment']}',"\
                  ' but the deployment does not exist.'
        errors.push(from_deployment_error_message) unless from_deployment
      end

      def create_consumer_intent(consumer, consumer_intent_params, consumes, metadata)
        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: consumer_intent_params[:original_name],
          link_type: consumer_intent_params[:type],
          new_intent_metadata: nil,
        )

        consumer_intent.name = consumer_intent_params[:alias].split('.')[-1]
        consumer_intent.blocked = consumer_intent_params[:blocked]
        consumer_intent.optional = consumes['optional'] || false
        consumer_intent.metadata = metadata.to_json
        consumer_intent.save
      end

      def process_manual_link(consumer, consumer_intent_params, manifest_source)
        manual_provider = @links_manager.find_or_create_provider(
          deployment_model: consumer.deployment,
          instance_group_name: consumer.instance_group,
          name: consumer.name,
          type: 'manual',
        )

        manual_provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: manual_provider,
          link_original_name: consumer_intent_params[:original_name],
          link_type: consumer_intent_params[:type],
        )

        content = {}
        MANUAL_LINK_KEYS.each do |key|
          content[key] = manifest_source[key]
        end

        content['deployment_name'] = consumer.deployment.name

        manual_provider_intent.name = consumer_intent_params[:original_name]
        manual_provider_intent.content = content.to_json
        manual_provider_intent.save
      end
    end

    class LinkHelpers
      def process_link_properties(job_properties, link_property_list, release_properties, job_name)
        errors = []
        link_property_list ||= []
        mapped_properties = {}
        default_properties = {
          'properties' => release_properties,
          'template_name' => job_name,
        }
        link_property_list.each do |link_property|
          property_path = link_property.split('.')
          result = find_property(property_path, job_properties)
          if !result['found']
            if (property = default_properties['properties'][link_property])
              mapped_properties = if (default_value = property['default'])
                                    update_mapped_properties(mapped_properties, property_path, default_value)
                                  else
                                    update_mapped_properties(mapped_properties, property_path, nil)
                                  end
            else
              errors.push("Link property #{link_property} in template #{default_properties['template_name']}"\
                        ' is not defined in release spec')
            end
          else
            mapped_properties = update_mapped_properties(mapped_properties, property_path, result['value'])
          end
        end
        [mapped_properties, errors]
      end

      def validate_custom_providers(
        manifest_defined_providers,
        release_defined_providers,
        job_name,
        instance_group_name,
        release_name
      )
        errors = []
        providers_grouped_by_name = manifest_defined_providers.group_by do |provider|
          provider['name']
        end

        duplicate_manifest_provider_names = providers_grouped_by_name.select do |_, val|
          val.size > 1
        end

        manifest_defined_providers.each do |custom_provider|
          errors.concat(validate_custom_provider_definition(custom_provider, job_name, instance_group_name))
          if release_defined_providers.detect { |provider| provider['name'] == custom_provider['name'] }
            errors.push("Custom provider '#{custom_provider['name']}' in job '#{job_name}' in instance group"\
                      " '#{instance_group_name}' is already defined in release '#{release_name}'")
          end
        end

        duplicate_manifest_provider_names.each_key do |duplicate_name|
          errors.push("Custom provider '#{duplicate_name}' in job '#{job_name}' in instance group"\
                    " '#{instance_group_name}' is defined multiple times in manifest.")
        end
        raise errors.join("\n") unless errors.empty?
      end

      def validate_custom_provider_definition(provider, job_name, instance_group_name)
        errors = []
        if !provider['name'].is_a?(String) || provider['name'].empty?
          errors.push("Name for custom link provider definition in manifest in job '#{job_name}' in instance group"\
                    " '#{instance_group_name}' must be a valid non-empty string.")
        end

        if !provider['type'].is_a?(String) || provider['type'].empty?
          errors.push("Type for custom link provider definition in manifest in job '#{job_name}' in instance group"\
                    " '#{instance_group_name}' must be a valid non-empty string.")
        end
        errors
      end

      def generate_provider_intent_params(manifest_source, provider_intent_params)
        if manifest_source.eql? 'nil'
          provider_intent_params[:consumable] = false
        else
          provider_intent_params[:alias] = manifest_source['as'] if manifest_source.key?('as')
          provider_intent_params[:shared] = double_negate_value(manifest_source['shared'])
        end
        provider_intent_params
      end

      def validate_provide_link(source, link_name, job_name, instance_group_name)
        return [] if source.eql? 'nil'

        unless source.is_a?(Hash)
          return ["Provider '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'"\
                " specified in the manifest should only be a hash or string 'nil'"]
        end

        errors = []
        if source.key?('name') || source.key?('type')
          errors.push("Cannot specify 'name' or 'type' properties in the manifest for link '#{link_name}'"\
                    " in job '#{job_name}' in instance group '#{instance_group_name}'."\
                    ' Please provide these keys in the release only.')
        end

        errors
      end

      def manual_link?(consume_link_source)
        MANUAL_LINK_KEYS.any? do |key|
          consume_link_source.key? key
        end
      end

      def find_property(property_path, job_properties)
        current_node = job_properties
        property_path.each do |key|
          return { 'found' => false, 'value' => nil } if !current_node || !current_node.key?(key)

          current_node = current_node[key]
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

      def extract_provider_definition_properties(manifest_details)
        are_custom_definitions = manifest_details.fetch(:are_custom_definitions, nil)
        instance_group_name = manifest_details.fetch(:instance_group_name, nil)
        job_name = manifest_details.fetch(:job_name, nil)
        job_properties = manifest_details.fetch(:job_properties, {})
        [are_custom_definitions, instance_group_name, job_name, job_properties]
      end

      def validate_consume_link(manifest_source, link_name, job_name, instance_group_name)
        return [] if manifest_source.eql? 'nil'

        unless manifest_source.is_a?(Hash)
          return ["Consumer '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'"\
                " specified in the manifest should only be a hash or string 'nil'"]
        end

        errors = []
        blacklist = [%w[instances from], %w[properties from]]
        blacklist.each do |invalid_props|
          if invalid_props.all? { |prop| manifest_source.key?(prop) }
            errors.push("Cannot specify both '#{invalid_props[0]}' and '#{invalid_props[1]}' keys for link"\
                      " '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'.")
          end
        end

        verify_consume_manifest_source_properties_instances(manifest_source, errors, link_name, job_name, instance_group_name)
        verify_consume_manifest_source_ip_addresses(manifest_source, errors, link_name, job_name, instance_group_name)
        verify_consume_manifest_source_name_type(manifest_source, errors, link_name, job_name, instance_group_name)

        errors
      end

      def verify_consume_manifest_source_properties_instances(source, errors, link_name, job_name, instance_group_name)
        error_message = "Cannot specify 'properties' without 'instances' for link '#{link_name}' in job '#{job_name}'"\
                  " in instance group '#{instance_group_name}'."
        errors.push(error_message) if source.key?('properties') && !source.key?('instances')
      end

      def verify_consume_manifest_source_ip_addresses(source, errors, link_name, job_name, instance_group_name)
        # The first expression makes it TRUE or FALSE then if the second expression is neither TRUE or FALSE it will return FALSE
        ip_addresses_error_message = "Cannot specify non boolean values for 'ip_addresses' field for link '#{link_name}'"\
                    " in job '#{job_name}' in instance group '#{instance_group_name}'."
        valid_property = (double_negate_value(source['ip_addresses']) != source['ip_addresses'])
        not_true_false = source.key?('ip_addresses') && valid_property

        errors.push(ip_addresses_error_message) if not_true_false
      end

      def verify_consume_manifest_source_name_type(source, errors, link_name, job_name, instance_group_name)
        name_type_error_message = "Cannot specify 'name' or 'type' properties in the manifest for link '#{link_name}'"\
                  " in job '#{job_name}' in instance group '#{instance_group_name}'."\
                  ' Please provide these keys in the release only.'
        errors.push(name_type_error_message) if source.key?('name') || source.key?('type')
      end

      def double_negate_value(value)
        (value && [true, false].include?(value)) || false
      end
    end

    def initialize
      @link_providers_parser = LinkProvidersParser.new
      @link_consumers_parser = LinkConsumersParser.new
    end

    def parse_migrated_from_providers_from_job(
      manifest_job_spec, deployment_model, current_template_model, manifest_details = {}
    )
      @link_providers_parser.parse_migrated_from_providers_from_job(
        manifest_job_spec, deployment_model, current_template_model, manifest_details
      )
    end

    def parse_providers_from_job(manifest_job_spec, deployment_model, current_release_template_model, manifest_details = {})
      @link_providers_parser.parse_providers_from_job(
        manifest_job_spec, deployment_model, current_release_template_model, manifest_details
      )
    end

    def parse_provider_from_disk(disk_spec, deployment_model, instance_group_name)
      @link_providers_parser.parse_provider_from_disk(
        disk_spec, deployment_model, instance_group_name
      )
    end

    def parse_migrated_from_consumers_from_job(
      manifest_job_spec, deployment_model, current_release_template_model, instance_group_details = {}
    )
      @link_consumers_parser.parse_migrated_from_consumers_from_job(
        manifest_job_spec, deployment_model, current_release_template_model, instance_group_details
      )
    end

    def parse_consumers_from_job(manifest_job_spec, deployment_model, current_release_template_model, instance_group_details = {})
      @link_consumers_parser.parse_consumers_from_job(
        manifest_job_spec, deployment_model, current_release_template_model, instance_group_details
      )
    end

    def parse_consumers_from_variable(variable_spec, deployment_model)
      return unless variable_spec.key? 'consumes'

      @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

      variable_name = variable_spec['name']
      variable_type = variable_spec['type']

      errors = []

      variable_spec['consumes'].each do |key, value|
        original_name = key

        local_error = validate_variable(variable_name, variable_type, original_name)

        unless local_error.nil?
          errors << local_error
          next
        end

        from_name = value['from'] || original_name

        consumer = @links_manager.find_or_create_consumer(
          deployment_model: deployment_model,
          instance_group_name: '',
          name: variable_name,
          type: 'variable',
        )

        metadata = { explicit_link: true }

        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: original_name,
          link_type: 'address',
          new_intent_metadata: metadata,
        )
        consumer_intent.name = from_name
        consumer_intent.save
      end

      raise errors.join("\n") unless errors.empty?
    end

    private

    def validate_variable(variable_name, variable_type, original_name)
      acceptable_combinations = { 'certificate' => ['alternative_name'] }

      unless acceptable_combinations.key?(variable_type)
        return "Variable '#{variable_name}' can not define 'consumes' key for type '#{variable_type}'"
      end

      unless acceptable_combinations[variable_type].include?(original_name)
        acceptable_combination_string = acceptable_combinations[variable_type].join(', ')
        return "Consumer name '#{original_name}' is not a valid consumer for variable '#{variable_name}'."\
                    " Acceptable consumer types are: #{acceptable_combination_string}"
      end

      nil
    end
  end
end
