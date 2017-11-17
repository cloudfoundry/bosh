module Bosh::Director::Models
  class LinkProvider < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment

    def validate
      validates_presence [
        :name,
        :shared,
        :deployment_id,
        :instance_group,
        :consumable,
        :content,
        :link_provider_definition_type,
        :link_provider_definition_name,
        :owner_object_type,
        :owner_object_name,
      ]
    end
  end
end