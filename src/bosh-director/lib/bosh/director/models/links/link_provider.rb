module Bosh::Director::Models::Links
  class LinkProvider < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment, :class => 'Bosh::Director::Models::Deployment'
    one_to_many :intents, :key => :link_provider_id, :class => 'Bosh::Director::Models::Links::LinkProviderIntent'

    def validate
      validates_presence [
        :deployment_id,
        :name,
        :type,
        :instance_group,
      ]
    end
  end
end