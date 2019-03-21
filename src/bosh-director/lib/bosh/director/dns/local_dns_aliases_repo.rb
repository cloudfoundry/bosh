module Bosh::Director
  class LocalDnsAliasesRepo
    def initialize(logger, root_domain)
      @dns_encoder = LocalDnsEncoderManager.create_dns_encoder
      @root_domain = root_domain
      @logger = logger
    end

    def update_for_deployment(deployment_model)
      model_diff = diff(deployment_model)
      @logger.debug(
        "Updating local dns aliases for deployment '#{deployment_model.name}': " \
        "obsolete: #{dump(model_diff[:obsolete])}, " \
        "new: #{dump(model_diff[:new])}, " \
        "unmodified: #{dump(model_diff[:unmodified])}",
      )

      model_diff[:new].each do |model|
        Models::LocalDnsAlias.create(model)
      end

      model_diff[:obsolete].each do |model|
        Models::LocalDnsAlias.where(model).delete
      end

      return unless model_diff[:new].empty? && !model_diff[:obsolete].empty?

      @logger.debug(
        "Deleting local dns aliases for deployment '#{deployment_model.name}' aliases: #{dump(model_diff[:obsolete])}",
      )
      Models::LocalDnsAlias.create(domain: "#{SecureRandom.uuid}-tombstone")
    end

    private

    def dump(aliases)
      strings = aliases.map do |a|
        "#{a[:domain]}: #{a}"
      end

      "{#{strings.sort.join(', ')}}"
    end

    def diff(deployment_model)
      existing_models = Models::LocalDnsAlias.where(deployment: deployment_model).map do |model|
        attrs = model.to_hash
        attrs.delete(:id)
        attrs
      end

      desired_models = calculate_desired(deployment_model)

      obsolete_models = existing_models - desired_models
      {
        new: desired_models - existing_models,
        obsolete: obsolete_models,
        unmodified: existing_models - obsolete_models,
      }
    end

    def calculate_desired(deployment_model)
      link_provider_intents = deployment_model.link_providers.flat_map(&:intents)

      link_provider_intents.flat_map do |provider_intent|
        next unless provider_intent.metadata

        aliases = JSON.parse(provider_intent.metadata)['dns_aliases']
        aliases&.map do |dns_alias|
          {
            deployment_id: deployment_model.id,
            domain: dns_alias['domain'],
            group_id: @dns_encoder.id_for_group_tuple(
              Models::LocalDnsEncodedGroup::Types::LINK,
              provider_intent.group_name,
              deployment_model.name,
            ),
            health_filter: dns_alias['health_filter'],
            initial_health_check: dns_alias['initial_health_check'],
            placeholder_type: dns_alias['placeholder_type'],
          }
        end
      end.compact
    end
  end
end
