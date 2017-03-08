module Bosh::Director::Models
  class Variable < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :variable_set, :class => 'Bosh::Director::Models::VariableSet'

    def validate
      validates_presence :variable_id
      validates_presence :variable_name
    end
  end
end
