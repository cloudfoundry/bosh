module Bosh::Director::Models

  class Deployment < Ohm::Model; end
  class Vm < Ohm::Model; end

  class Instance < Ohm::Model
    reference :deployment, Deployment
    attribute :job
    attribute :index
    reference :vm, Vm
    attribute :disk_cid

    index :job
    index :index

    def validate
      assert_present :deployment_id
      assert_present :job
      assert_present :index
      assert_unique_if_present :vm_id
      assert_unique [:deployment_id, :job, :index]
    end
  end
end
