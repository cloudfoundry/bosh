module Bosh::Director::Models
  class Instance < Sequel::Model
    many_to_one :deployment
    many_to_one :vm

    def validate
      validates_presence [:deployment_id, :job, :index, :state]
      validates_unique [:deployment_id, :job, :index]
      validates_unique [:vm_id] if vm_id
      validates_unique [:disk_cid] if disk_cid
      validates_integer :index
      validates_includes ["started", "stopped", "detached"], :state
    end

  end
end
