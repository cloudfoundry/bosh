module Bosh::Director::Models
  class Vm < Sequel::Model
    many_to_one :deployment
    one_to_one  :instance

    def validate
      validates_presence [:deployment_id, :agent_id]
      validates_unique :agent_id
    end
  end
end
