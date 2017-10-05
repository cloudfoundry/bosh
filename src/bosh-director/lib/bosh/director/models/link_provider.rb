module Bosh::Director::Models
  class LinkProvider < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment

    def validate
      validates_presence [
        :name,
        :deployment_id,
        :shared,
        :consumable,
        :link_provider_definition_type,
        :link_provider_definition_name,
        :owner_object_type,
      ]
    end
  end
end