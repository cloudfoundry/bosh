module Bosh::Director::Models
  class ErrandRun < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
  end
end
