module Bosh::Director::Models

  class Deployment < Ohm::Model; end
  class Vm < Ohm::Model; end

  class Instance < Ohm::Model
    reference :deployment, Deployment
    attribute :job
    attribute :index
    reference :vm, Vm
    attribute :disk_cid

    index :deployment
    index :job
    index :index
    index :vm

    def validate
      assert_present :deployment
      assert_present :job
      assert_present :index
      assert_unique :vm
    end
  end
end
