module Bosh::Director::Models::ConfigServer
  class Deployment < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instances

    def validate
      validates_presence :placeholder_name
      validates_presence :placeholder_id
    end
  end
end
