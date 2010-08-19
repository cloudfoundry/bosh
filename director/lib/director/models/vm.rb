module Bosh::Director::Models

  class Deployment < Ohm::Model; end

  class Vm < Ohm::Model
    reference :deployment, Deployment
    attribute :agent_id
    attribute :cid

    index :deployment

    def validate
      assert_present :deployment
      assert_present :agent_id
      assert_present :cid
    end
  end
end
