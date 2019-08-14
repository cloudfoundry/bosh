module Bosh::Director::Links
  class LinksParser
    include Bosh::Director::ValidationHelper

    MANUAL_LINK_KEYS = %w[instances properties address].freeze

    def initialize
      @link_providers_parser = LinkProvidersParser.new
      @link_consumers_parser = LinkConsumersParser.new
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

        metadata = { 'explicit_link' => true }
        wildcard_needed = !value['properties'].nil? && value['properties']['wildcard'] == true
        metadata = metadata.merge('wildcard' => wildcard_needed)

        consumer_intent = @links_manager.find_or_create_consumer_intent(
          link_consumer: consumer,
          link_original_name: original_name,
          link_type: value['link_type'] || 'address',
          new_intent_metadata: metadata,
        )
        consumer_intent.name = from_name
        consumer_intent.save
      end

      raise errors.join("\n") unless errors.empty?
    end

    private

    def validate_variable(variable_name, variable_type, original_name)
      acceptable_combinations = { 'certificate' => %w[alternative_name common_name] }

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
