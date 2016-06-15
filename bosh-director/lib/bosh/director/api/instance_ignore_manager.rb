module Bosh::Director
  module Api
    class InstanceIgnoreManager
      def set_ignore_state_for_instance(deployment, instance_group_name, instance_group_id, state)
        instance = InstanceLookup.new.by_uuid(deployment, instance_group_name, instance_group_id)
        instance.ignore = state
        instance.save
      end
    end
  end
end
