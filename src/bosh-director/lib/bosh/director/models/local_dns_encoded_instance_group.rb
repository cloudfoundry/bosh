module Bosh::Director::Models
  class LocalDnsEncodedInstanceGroup < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
  end
end
