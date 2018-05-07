module Bosh::Director::Models
  class OrphanedVm < Sequel::Model(Bosh::Director::Config.db)
    one_to_many :ip_addresses
  end
end
