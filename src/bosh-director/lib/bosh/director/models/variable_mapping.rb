module Bosh::Director::Models
  class VariableMapping < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment

    def validate
      validates_presence :variable_name
      validates_presence :variable_id
    end
  end
end
