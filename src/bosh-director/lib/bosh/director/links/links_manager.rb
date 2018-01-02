module Bosh::Director::Links
  class LinksManager
    def find_or_create_provider(
      deployment_model:,
      instance_group_name:,
      name:,
      type:
    )
      Bosh::Director::Models::Links::LinkProvider.find_or_create(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name,
        type: type
      )
    end

    def find_provider(
      deployment_model:,
      instance_group_name:,
      name:
    )
      Bosh::Director::Models::Links::LinkProvider.find(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name
      )
    end

    def find_or_create_provider_intent(
      link_provider:,
      link_name:,
      link_type:
    )
      Bosh::Director::Models::Links::LinkProviderIntent.find_or_create(
        link_provider: link_provider,
        original_name: link_name,
        type: link_type,
        consumable: true
      )
    end

    def find_provider_intent(
      link_provider:,
      link_name:,
      link_alias:,
      link_type:
    )
      if link_alias
        Bosh::Director::Models::Links::LinkProviderIntent.find(
          link_provider: link_provider,
          name: link_alias,
          type: link_type,
          consumable: true
        )
      elsif link_name
        Bosh::Director::Models::Links::LinkProviderIntent.find(
          link_provider: link_provider,
          original_name: link_name,
          type: link_type,
          consumable: true
        )
      end
    end

    def find_or_create_consumer(
      deployment_model:,
      instance_group_name:,
      name:,
      type:
    )
      Bosh::Director::Models::Links::LinkConsumer.find_or_create(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name,
        type: type
      )
    end

    def find_consumer(
      deployment_model:,
      instance_group_name:,
      name:
    )
      Bosh::Director::Models::Links::LinkConsumer.find(
        deployment: deployment_model,
        instance_group: instance_group_name,
        name: name
      )
    end

    def find_or_create_consumer_intent(
      link_consumer:,
      original_link_name:,
      link_type:,
      optional:,
      blocked:
    )
      Bosh::Director::Models::Links::LinkConsumerIntent.find_or_create(
        link_consumer: link_consumer,
        original_name: original_link_name,
        type: link_type,
        optional: optional,
        blocked: blocked
      )
    end

    def find_or_create_link(
      name:,
      provider_intent:,
      consumer_intent:,
      link_content:
    )
      found_link = Bosh::Director::Models::Links::Link.find(
        link_provider_intent_id: provider_intent && provider_intent[:id],
        link_consumer_intent_id: consumer_intent && consumer_intent[:id],
        link_content: link_content
      )

      if !found_link
        Bosh::Director::Models::Links::Link.create(
          name: name,
          link_provider_intent_id: provider_intent && provider_intent[:id],
          link_consumer_intent_id: consumer_intent && consumer_intent[:id],
          link_content: link_content
        )
      end
    end

    def find_link(
      name:,
      provider_intent:,
      consumer_intent:
    )
      Bosh::Director::Models::Links::Link.find(
        link_provider_intent_id: provider_intent && provider_intent[:id],
        link_consumer_intent_id: consumer_intent && consumer_intent[:id],
        name: name
      )
    end
  end
end