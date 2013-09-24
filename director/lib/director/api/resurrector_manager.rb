module Bosh::Director
  module Api
    class ResurrectorManager
      def set_pause_for_instance(deployment_name, job_name, job_index, desired_state)
        instance = InstanceLookup.new.by_attributes(deployment_name, job_name, job_index)
        instance.resurrection_paused = desired_state
        instance.save
      end

      def set_pause_for_all(desired_state)
        Models::Instance.update(resurrection_paused: desired_state)
      end
    end
  end
end