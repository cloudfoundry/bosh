module Bosh::Director::Models

  class Deployment < Ohm::Model; end

  class Vm < Ohm::Model
    reference :deployment, Deployment
    attribute :agent_id
    attribute :cid

    index :agent_id

    def validate
      assert_present :deployment_id
      assert_present :agent_id
      assert_present :cid
      assert_unique :agent_id
    end
  end
end
