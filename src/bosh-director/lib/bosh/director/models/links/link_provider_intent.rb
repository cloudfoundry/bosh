module Bosh::Director::Models::Links
  class LinkProviderIntent < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :link_provider, :key => :link_provider_id, :class => 'Bosh::Director::Models::Links::LinkProvider'
    one_to_many :links, :key => :link_provider_intent_id, :class => 'Bosh::Director::Models::Links::Link'

    def validate
      validates_presence [
                           :original_name,
                           :link_provider_id,
                           :type
                         ]
    end
  end
end
