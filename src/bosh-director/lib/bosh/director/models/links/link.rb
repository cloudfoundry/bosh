module Bosh::Director::Models::Links
  class Link < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :link_provider_intent, :key => :link_provider_intent_id, :class => 'Bosh::Director::Models::Links::LinkProviderIntent'
    many_to_one :link_consumer_intent, :key => :link_consumer_intent_id, :class => 'Bosh::Director::Models::Links::LinkConsumerIntent'

    def before_create
      self.created_at ||= Time.now
    end

    def validate
      validates_presence [
                           :name,
                           :link_consumer_intent_id,
                           :link_content
                         ]
    end
  end
end