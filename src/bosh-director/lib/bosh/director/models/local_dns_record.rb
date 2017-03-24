module Bosh::Director::Models
  class LocalDnsRecord  < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
  end
end
