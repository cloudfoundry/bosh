module Bosh::Director::Models
  class LocalDnsServiceGroup < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance_group, :class => 'Bosh::Director::Models::LocalDnsEncodedInstanceGroup'
    many_to_one :network, :class => 'Bosh::Director::Models::LocalDnsEncodedNetwork'

    def self.all_groups_eager_load
      self.eager(instance_group: :deployment).eager(:network).all
    end
  end
end
