module Bosh::Director
  module Api
    class ResurrectorManager
      def set_pause_for_instance(deployment, job_name, index_or_id, desired_state)

        # This is for backwards compatibility and can be removed when we move to referencing job by instance id only.
        if index_or_id.to_s =~ /^\d+$/
          instance = InstanceLookup.new.by_attributes(deployment, job_name, index_or_id)
        else
          instance = InstanceLookup.new.by_uuid(deployment, job_name, index_or_id)
        end

        instance.resurrection_paused = desired_state
        instance.save
      end

      def set_pause_for_all(desired_state)
        Models::DirectorAttribute.create(name: 'resurrection_paused', value: desired_state.to_s)
      rescue Sequel::ValidationFailed, Sequel::DatabaseError => e
        error_message = e.message.downcase
        if error_message.include?('unique') || error_message.include?('duplicate')
          Models::DirectorAttribute.where(name: 'resurrection_paused').update(value: desired_state.to_s)
        else
          raise e
        end
      end

      def pause_for_all?
        record = Models::DirectorAttribute.first(name: 'resurrection_paused')
        record.nil? || record.value == "false" ? false : true
      end
    end
  end
end
