module Bosh::Director::Models::Links
  class LinkConsumer < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment, :class => 'Bosh::Director::Models::Deployment'
    one_to_many :intents, :key => :link_consumer_id, :class => 'Bosh::Director::Models::Links::LinkConsumerIntent'

    def validate
      validates_presence [
        :deployment_id,
        :instance_group,
        :name,
        :type
      ]
    end
  end
end