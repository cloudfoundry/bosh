module Bosh::Director::Models
  class LinkConsumer < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment

    def validate
      validates_presence [
        :deployment_id,
        :owner_object_name,
        :owner_object_type
      ]
    end
  end
end