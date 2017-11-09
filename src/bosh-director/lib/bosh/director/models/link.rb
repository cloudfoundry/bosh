module Bosh::Director::Models
  class Link < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :link_consumer, :class => 'Bosh::Director::Models::LinkConsumer'
    many_to_one :link_provider, :class => 'Bosh::Director::Models::LinkProvider'

    def before_create
      self.created_at ||= Time.now
    end

    def validate
      validates_presence [:name, :link_consumer_id, :link_content, :created_at]
    end
  end
end