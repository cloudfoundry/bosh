module Bosh::Director
  class InstanceUpdater::InstanceState
    def self.with_instance_update(instance_model)
      instance_model.update(update_completed: false)
      yield
      instance_model.update(update_completed: true)
    end
  end
end
