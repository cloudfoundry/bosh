module Bosh::Director::Links
  class LinksErrorBuilder
    def self.build_link_error(consumer_intent, provider_intents, expected_network = nil)
      error_header = build_link_error_header(consumer_intent)

      error_header << ' Multiple link providers found:' if provider_intents.size > 1
      error_header << ' Details below:' if provider_intents.size <= 1

      error_details = build_error_details(provider_intents, expected_network).map do |detail|
        "    - #{detail}"
      end

      "#{error_header}\n#{error_details.join("\n")}"
    end

    private_class_method def self.build_link_error_header(consumer_intent)
      consumer = consumer_intent.link_consumer
      link_original_name = consumer_intent.original_name
      link_alias_name = consumer_intent.name
      alias_differs = link_original_name != link_alias_name
      link_type = consumer_intent.type
      error_heading = "Failed to resolve link '#{link_original_name}' with "
      error_heading << "alias '#{link_alias_name}' and " if alias_differs
      error_heading << "type '#{link_type}' from "

      case consumer.type
      when 'variable'
        error_heading << "variable '#{consumer.name}'."
      else
        error_heading << "job '#{consumer.name}'"
        if consumer.instance_group.nil? || consumer.instance_group.empty?
          error_heading << '.'
        else
          error_heading << " in instance group '#{consumer.instance_group}'."
        end
      end
      error_heading
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    private_class_method def self.build_error_details(provider_intents, expected_network = nil)
      return ['No link providers found'] if provider_intents.empty?
      error_details = []
      provider_intents.each do |provider_intent|
        provider = provider_intent.link_provider
        case provider.type
        when 'disk'
          error_detail = "Disk link provider '#{provider_intent.original_name}' "
          error_detail << "from instance group '#{provider.instance_group}'"
          error_detail << ' does not contain any networks' unless expected_network.nil?
        when 'variable'
          error_detail = "Link provider '#{provider_intent.original_name}' "
          error_detail << "from variable '#{provider.name}'"
          error_detail << ' does not contain any networks' unless expected_network.nil?
        else
          link_original_name = provider_intent.original_name
          link_alias_name = provider_intent.name
          alias_differs = link_original_name != link_alias_name
          error_detail = "Link provider '#{provider_intent.original_name}' "
          error_detail << "with alias '#{provider_intent.name}' " if alias_differs
          error_detail << "from job '#{provider.name}' "
          error_detail << "in instance group '#{provider.instance_group}' "
          error_detail << "in deployment '#{provider.deployment.name}'"
          error_detail << " does not belong to network '#{expected_network}'" unless expected_network.nil?
        end
        error_details << error_detail
      end
      error_details
    end
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
