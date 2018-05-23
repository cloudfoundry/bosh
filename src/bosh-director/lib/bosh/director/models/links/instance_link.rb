module Bosh::Director::Models::Links
  class InstancesLink < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance, :class => 'Bosh::Director::Models::Instance'
    many_to_one :link, :class => 'Bosh::Director::Models::Links::Link'
  end
end