module Bosh::Director::Models::Links
  class Link < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :link_provider_intent, key: :link_provider_intent_id, class: 'Bosh::Director::Models::Links::LinkProviderIntent'
    many_to_one :link_consumer_intent, key: :link_consumer_intent_id, class: 'Bosh::Director::Models::Links::LinkConsumerIntent'
    many_to_many :instances, join_table: :instances_links

    def before_create
      self.created_at ||= Time.now
    end

    def validate
      validates_presence %i[
        name
        link_consumer_intent_id
        link_content
      ]
    end

    def group_name
      return '' if link_provider_intent.nil?

      link_name = link_provider_intent.name || link_provider_intent.original_name
      link_type = link_provider_intent.type

      "#{link_name}-#{link_type}"
    end
  end
end
