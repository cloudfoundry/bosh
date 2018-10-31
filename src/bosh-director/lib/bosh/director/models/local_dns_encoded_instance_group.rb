module Bosh::Director::Models
  class LocalDnsEncodedGroup < Sequel::Model(Bosh::Director::Config.db)
    module Types
      INSTANCE_GROUP = 'instance-group'.freeze
      LINK = 'link'.freeze
    end

    many_to_one :deployment
  end
end
