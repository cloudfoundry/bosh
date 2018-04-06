module Bosh::Director::Models::Links
  class LinkConsumerIntent < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :link_consumer, :class => 'Bosh::Director::Models::Links::LinkConsumer'
    one_to_many :links, :key => :link_consumer_intent_id, :class => 'Bosh::Director::Models::Links::Link'

    def validate
      validates_presence [:link_consumer_id, :original_name, :type]
    end
  end
end