module Bosh::Director::Models
  class LocalDnsRecord  < Sequel::Model(Bosh::Director::Config.db)
    one_to_one :instances
  end
end
