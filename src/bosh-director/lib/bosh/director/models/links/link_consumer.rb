module Bosh::Director::Models::Links
  class LinkConsumer < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment, :class => 'Bosh::Director::Models::Deployment'

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