module Bosh::Director::Models::Links
  class LinkProvider < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment, :class => 'Bosh::Director::Models::Deployment'
    one_to_many :intents, :key => :link_provider_id, :class => 'Bosh::Director::Models::Links::LinkProviderIntent'

    def validate
      validates_presence [
        :deployment_id,
        :instance_group,
        :name,
        :type
      ]
    end

    def find_intent_by_name(name)
      intents_dataset.where(original_name: name).limit(1).first
    end
  end
end
