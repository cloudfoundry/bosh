module Bosh::Director::Models::Links
  class InstancesLink < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instances, :class => 'Bosh::Director::Models::Instances'
    many_to_one :links, :class => 'Bosh::Director::Models::Links::Link'
  end
end