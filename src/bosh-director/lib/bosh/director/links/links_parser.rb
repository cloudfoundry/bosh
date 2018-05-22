module Bosh::Director::Links
  class LinksParser
    include Bosh::Director::ValidationHelper

    MANUAL_LINK_KEYS = ['instances', 'properties', 'address']

    def parse_migrated_from_providers_from_job(manifest_job_spec, deployment_model, current_template_model, job_properties, instance_group_name, migrated_from)
      migrated_from.each do |migration_block|
        old_instance_group_name = migration_block['name']
        job_name = safe_property(manifest_job_spec, 'name', class: String)

        providers = Bosh::Director::Models::Links::LinkProvider.find(
          deployment: deployment_model,
          instance_group: old_instance_group_name,
          name: job_name,
          type: 'job'
        )

        unless providers.nil?
          instance_group_name = migration_block['name']
        end
      end

      parse_providers_from_job(manifest_job_spec, deployment_model, current_template_model, job_properties, instance_group_name)
    end

    def parse_migrated_from_consumers_from_job(manifest_job_spec, deployment_model, current_release_template_model, instance_group_name, migrated_from)
      migrated_from.each do |migration_block|
        old_instance_group_name = migration_block['name']
        job_name = safe_property(manifest_job_spec, 'name', class: String)

        consumers = Bosh::Director::Models::Links::LinkConsumer.find(
          deployment: deployment_model,
          instance_group: old_instance_group_name,
          name: job_name,
          type: 'job'
        )

        unless consumers.nil?
          instance_group_name = migration_block['name']
        end
      end

      parse_consumers_from_job(manifest_job_spec, deployment_model, current_release_template_model, instance_group_name)
    end

    def validate_custom_providers(manifest_defined_providers, release_defined_providers, job_name, instance_group_name, release_name)
      errors = []
      duplicate_manifest_provider_names = manifest_defined_providers.group_by do |provider|
        provider['name']
      end.select do |key, val|
        val.size > 1
      end

      manifest_defined_providers.each do |custom_provider, index|
        errors.concat(validate_custom_provider_definition(custom_provider, job_name, instance_group_name))
        errors.push("Custom provider '#{custom_provider['name']}' in job '#{job_name}' in instance group '#{instance_group_name}' is already defined in release '#{release_name}'") if release_defined_providers.detect {|provider| provider['name'] == custom_provider['name']}
      end

      duplicate_manifest_provider_names.each do |duplicate_name, _|
        errors.push("Custom provider '#{duplicate_name}' in job '#{job_name}' in instance group '#{instance_group_name}' is defined multiple times in manifest.")
      end
      raise errors.join("\n") unless errors.empty?
    end

    def parse_providers_from_job(manifest_job_spec, deployment_model, current_release_template_model, job_properties, instance_group_name)
      @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

      manifest_provides_links = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'provides', class: Hash, optional: true, default: {}))
      custom_manifest_providers = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'custom_provider_definitions', class: Array, optional: true, default: []))
      job_name = safe_property(manifest_job_spec, 'name', class: String)

      validate_custom_providers(custom_manifest_providers, current_release_template_model.provides, job_name, instance_group_name, current_release_template_model.release.name)

      errors = []

      errors.concat(process_custom_providers(current_release_template_model, custom_manifest_providers, manifest_provides_links, deployment_model, job_properties, instance_group_name))
      errors.concat(process_release_providers(current_release_template_model, manifest_provides_links, deployment_model, instance_group_name, job_properties))

      unless manifest_provides_links.empty?
        errors.push("Manifest defines unknown providers:")
        manifest_provides_links.each do |link_name, _|
          errors.push("  - Job '#{job_name}' does not provide link '#{link_name}' in the release spec")
        end
      end

      unless errors.empty?
        raise errors.join("\n")
      end
    end

    def parse_consumers_from_job(manifest_job_spec, deployment_model, current_release_template_model, instance_group_name)
      @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

      consumes_links = Bosh::Common::DeepCopy.copy(safe_property(manifest_job_spec, 'consumes', class: Hash, optional: true, default: {}))
      job_name = safe_property(manifest_job_spec, 'name', class: String)

      if current_release_template_model.consumes.empty? && !consumes_links.empty?
        raise "Job '#{job_name}' in instance group '#{instance_group_name}' specifies consumers in the manifest but the job does not define any consumers in the release spec"
      end

      return if current_release_template_model.consumes.empty?

      consumer = @links_manager.find_or_create_consumer(
        deployment_model: deployment_model,
        instance_group_name: instance_group_name,
        name: job_name,
        type: 'job'
      )

      errors = []

      current_release_template_model.consumes.each do |consumes|
        consumed_link_original_name = consumes["name"]

        consumer_intent_params = {
          original_name: consumed_link_original_name,
          alias: consumed_link_original_name,
          blocked: false,
          type: consumes['type']
        }

        metadata = {}

        if !consumes_links.has_key?(consumed_link_original_name)
          metadata[:explicit_link] = false
        else
          manifest_source = consumes_links.delete(consumed_link_original_name)

          new_errors = validate_consume_link(manifest_source, consumed_link_original_name, job_name, instance_group_name)
          errors.concat(new_errors)
          next unless new_errors.empty?

          metadata[:explicit_link] = true

          if manifest_source.eql? 'nil'
            consumer_intent_params[:blocked] = true
          else
            if is_manual_link? manifest_source
              metadata[:manual_link] = true
              process_manual_link(consumer, consumer_intent_params, manifest_source)
            else
              consumer_intent_params[:alias] = manifest_source['from'] if manifest_source.has_key?('from')

              metadata[:ip_addresses] = manifest_source['ip_addresses'] if manifest_source.has_key?('ip_addresses')
              metadata[:network] = manifest_source['network'] if manifest_source.has_key?('network')
              if manifest_source['deployment']
                from_deployment = Bosh::Director::Models::Deployment.find(name: manifest_source['deployment'])
                if from_deployment
                  metadata[:from_deployment] = manifest_source['deployment']
                else
                  errors.push("Link '#{consumed_link_original_name}' in job '#{job_name}' from instance group '#{instance_group_name}' consumes from deployment '#{manifest_source['deployment']}', but the deployment does not exist.")
                  next
                end
              end
            end
          end
        end

        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: consumer_intent_params[:original_name],
          link_type: consumer_intent_params[:type],
          new_intent_metadata: nil,
        )
        consumer_intent.name = consumer_intent_params[:alias].split(".")[-1]
        consumer_intent.blocked = consumer_intent_params[:blocked]
        consumer_intent.optional = consumes['optional'] || false
        consumer_intent.metadata = metadata.to_json
        consumer_intent.save
      end

      unless consumes_links.empty?
        errors.push("Manifest defines unknown consumers:")
        consumes_links.each do |link_name, _|
          errors.push(" - Job '#{job_name}' does not define consumer '#{link_name}' in the release spec")
        end
      end

      unless errors.empty?
        raise errors.join("\n")
      end
    end

    def parse_provider_from_disk(disk_spec, deployment_model, instance_group_name)
      @links_manager = Bosh::Director::Links::LinksManager.new(deployment_model.links_serial_id)

      disk_name = disk_spec['name'] # All the parsing we need

      provider = @links_manager.find_or_create_provider(
        deployment_model: deployment_model,
        instance_group_name: instance_group_name,
        name: instance_group_name,
        type: 'disk'
      )

      provider_intent = @links_manager.find_or_create_provider_intent(
        link_provider: provider,
        link_original_name: disk_name,
        link_type: 'disk'
      )

      provider_intent.shared = false
      provider_intent.name = disk_name
      provider_intent.content = Bosh::Director::DeploymentPlan::DiskLink.new(deployment_model.name, disk_name).spec.to_json
      provider_intent.save
    end

    private

    def process_providers(release_properties, provider_definitions, manifest_provides_links, deployment_model, job_properties, instance_group_name, job_name, are_custom_definitions)
      provider = @links_manager.find_or_create_provider(
        deployment_model: deployment_model,
        instance_group_name: instance_group_name,
        name: job_name,
        type: 'job',
        )

      errors = []

      provider_definitions.each do |provider_definition|
        provider_original_name = provider_definition['name']

        provider_intent_params = {
          original_name: provider_original_name,
          type: provider_definition['type'],
          alias: provider_original_name,
          shared: false,
          consumable: true
        }

        if manifest_provides_links.has_key?(provider_original_name)
          manifest_source = manifest_provides_links.delete(provider_original_name)

          validation_errors = validate_provide_link(manifest_source, provider_original_name, job_name, instance_group_name)
          errors.concat(validation_errors)
          next unless validation_errors.empty?

          if manifest_source.eql? 'nil'
            provider_intent_params[:consumable] = false
          else
            provider_intent_params[:alias] = manifest_source['as'] if manifest_source.has_key?('as')
            provider_intent_params[:shared] = !!manifest_source['shared']
          end
        end

        exported_properties = provider_definition['properties'] || []
        default_job_properties = {
          'properties' => release_properties,
          'template_name' => job_name
        }

        mapped_properties, properties_errors = process_link_properties(job_properties, default_job_properties, exported_properties)
        errors.concat(properties_errors)

        next unless properties_errors.empty?

        provider_intent = @links_manager.find_or_create_provider_intent(
          link_provider: provider,
          link_original_name: provider_intent_params[:original_name],
          link_type: provider_intent_params[:type]
        )

        provider_intent.name = provider_intent_params[:alias]
        provider_intent.shared = provider_intent_params[:shared]
        is_custom = are_custom_definitions || false
        provider_intent.metadata = {:mapped_properties => mapped_properties, :custom => is_custom}.to_json
        provider_intent.consumable = provider_intent_params[:consumable]
        provider_intent.save
      end
      errors
    end

    def process_custom_providers(current_release_template_model, custom_manifest_providers, manifest_provides_links, deployment_model, job_properties, instance_group_name)
      return [] if custom_manifest_providers.empty?

      process_providers(current_release_template_model.properties, custom_manifest_providers, manifest_provides_links, deployment_model,
                        job_properties, instance_group_name, current_release_template_model.name, true)
    end

    def process_release_providers(current_release_template_model, manifest_provides_links, deployment_model, instance_group_name, job_properties)
      job_name = current_release_template_model.name

      if current_release_template_model.provides.empty? && !manifest_provides_links.empty?
        raise "Job '#{job_name}' in instance group '#{instance_group_name}' specifies providers in the manifest but the job does not define any providers in the release spec"
      end

      return [] if current_release_template_model.provides.empty?

      process_providers(current_release_template_model.properties, current_release_template_model.provides, manifest_provides_links, deployment_model,
                        job_properties, instance_group_name, job_name, false)
    end

    def validate_custom_provider_definition(provider, job_name, instance_group_name)
      errors = []
      errors.push("Name for custom link provider definition in manifest in job '#{job_name}' in instance group '#{instance_group_name}' must be a valid non-empty string.") if !provider['name'].is_a?(String) || provider['name'].empty?
      errors.push("Type for custom link provider definition in manifest in job '#{job_name}' in instance group '#{instance_group_name}' must be a valid non-empty string.") if !provider['type'].is_a?(String) || provider['type'].empty?
      errors
    end

    def validate_provide_link(source, link_name, job_name, instance_group_name)
      if source.eql? 'nil'
        return []
      end

      unless source.kind_of?(Hash)
        return ["Provider '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}' specified in the manifest should only be a hash or string 'nil'"]
      end

      errors = []
      if source.has_key?('name') || source.has_key?('type')
        errors.push("Cannot specify 'name' or 'type' properties in the manifest for link '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'. Please provide these keys in the release only.")
      end

      errors
    end

    def process_link_properties(job_properties, default_properties, link_property_list)
      errors = []
      mapped_properties = {}
      link_property_list.each do |link_property|
        property_path = link_property.split('.')
        result = find_property(property_path, job_properties)
        if !result['found']
          if default_properties['properties'].key?(link_property)
            if default_properties['properties'][link_property].key?('default')
              mapped_properties = update_mapped_properties(mapped_properties, property_path, default_properties['properties'][link_property]['default'])
            else
              mapped_properties = update_mapped_properties(mapped_properties, property_path, nil)
            end
          else
            errors.push("Link property #{link_property} in template #{default_properties['template_name']} is not defined in release spec")
          end
        else
          mapped_properties = update_mapped_properties(mapped_properties, property_path, result['value'])
        end
      end
      [mapped_properties, errors]
    end

    def find_property(property_path, job_properties)
      current_node = job_properties
      property_path.each do |key|
        if !current_node || !current_node.key?(key)
          return {'found' => false, 'value' => nil}
        else
          current_node = current_node[key]
        end
      end
      {'found' => true, 'value' => current_node}
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

    def validate_consume_link(source, link_name, job_name, instance_group_name)
      if source.eql? 'nil'
        return []
      end

      unless source.kind_of?(Hash)
        return ["Consumer '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}' specified in the manifest should only be a hash or string 'nil'"]
      end

      errors = []
      blacklist = [['instances', 'from'], ['properties', 'from']]
      blacklist.each do |invalid_props|
        if invalid_props.all? {|prop| source.has_key?(prop)}
          errors.push("Cannot specify both '#{invalid_props[0]}' and '#{invalid_props[1]}' keys for link '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'.")
        end
      end

      if source.has_key?('properties') && !source.has_key?('instances')
        errors.push("Cannot specify 'properties' without 'instances' for link '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'.")
      end

      if source.has_key?('ip_addresses')
        # The first expression makes it TRUE or FALSE then if the second expression is neither TRUE or FALSE it will return FALSE
        unless (!!source['ip_addresses']) == source['ip_addresses']
          errors.push("Cannot specify non boolean values for 'ip_addresses' field for link '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'.")
        end
      end

      if source.has_key?('name') || source.has_key?('type')
        errors.push("Cannot specify 'name' or 'type' properties in the manifest for link '#{link_name}' in job '#{job_name}' in instance group '#{instance_group_name}'. Please provide these keys in the release only.")
      end

      errors
    end

    def process_manual_link(consumer, consumer_intent_params, manifest_source)
      manual_provider = @links_manager.find_or_create_provider(
        deployment_model: consumer.deployment,
        instance_group_name: consumer.instance_group,
        name: consumer.name,
        type: 'manual'
      )

      manual_provider_intent = @links_manager.find_or_create_provider_intent(
        link_provider: manual_provider,
        link_original_name: consumer_intent_params[:original_name],
        link_type: consumer_intent_params[:type]
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

    def is_manual_link?(consume_link_source)
      MANUAL_LINK_KEYS.any? do |key|
        consume_link_source.has_key? key
      end
    end
  end
end