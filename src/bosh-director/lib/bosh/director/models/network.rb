module Bosh::Director::Models
  class Network < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :deployments
    one_to_many :subnets

    def validate
      validates_presence :name
      validates_unique :name
    end
  end
end
