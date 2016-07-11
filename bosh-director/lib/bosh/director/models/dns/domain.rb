module Bosh::Director::Models::Dns
  class Domain < Sequel::Model(Bosh::Director::Config.dns_db)
    extend Bosh::Director::ModelHelper

    one_to_many :records
  end
end
