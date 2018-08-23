module Bosh::Director::Models
  class Subnet < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :network
  end
end
