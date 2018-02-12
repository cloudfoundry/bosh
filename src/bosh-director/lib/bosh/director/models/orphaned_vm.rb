module Bosh::Director::Models
  class OrphanedVm < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance
    one_to_many :ip_addresses
  end
end
