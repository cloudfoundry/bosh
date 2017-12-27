module Bosh::Director::Models::Links
  class LinkConsumerIntent < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :consumer, :class => 'Bosh::Director::Models::Links::LinkConsumer'
    one_to_many :links, :key => :link_consumer_intent_id, :class => 'Bosh::Director::Models::Links::Link'

    def validate
      validates_presence [:consumer_id, :name, :type, :optional, :blocked]
    end
  end
end