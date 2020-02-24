module Bosh::Director
  module Api
    class InstanceIgnoreManager
      def set_ignore_state_for_instance(deployment, instance_group_name, index_or_id, state)
        if index_or_id == "*"
           instances = Api::InstanceManager.new.find_instances_by_job(deployment, instance_group_name)
           instances.each do |instance|
             instance.ignore = state
             instance.save
           end
        else
           instance = Api::InstanceManager.new.find_by_name(deployment, instance_group_name, index_or_id)
           instance.ignore = state
           instance.save
        end
      end
    end
  end
end
