module Bosh::Director::Links
  class LinksParser
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
              mapped_properties = update_mapped_properties(mapped_properties, property_path, property['default'])
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
          provider_intent_params['consumable'] = false
        else
          provider_intent_params['alias'] = manifest_source['as'] if manifest_source.key?('as')
          provider_intent_params['shared'] = double_negate_value(manifest_source['shared'])
          provider_intent_params['dns_aliases'] = manifest_source['aliases'] if manifest_source.key?('aliases')
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
  end
end
