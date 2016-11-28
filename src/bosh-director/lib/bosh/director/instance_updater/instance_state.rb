module Bosh::Director
  class InstanceUpdater::InstanceState
    def self.with_instance_update(instance_model, &update_procedure)
      instance_model.update(update_completed: false)
      update_procedure.call
      instance_model.update(update_completed: true)
    end

    def self.with_instance_update_and_event_creation(instance_model, parent_id, deployment_name, action, &update_procedure)
      begin
        self.with_instance_update(instance_model, &update_procedure)
      rescue Exception => e
        raise e
      ensure
        Config.current_job.event_manager.create_event(
          {
            parent_id: parent_id,
            user: Config.current_job.username,
            action: action,
            object_type: 'instance',
            object_name: instance_model.name,
            task: Config.current_job.task_id,
            deployment: deployment_name,
            instance: instance_model.name,
            error: e,
            context: {}
          })
      end
    end
  end
end
