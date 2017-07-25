module Bosh::Director
  class Errand::ErrandInstanceUpdater
    def initialize(job_manager, logger, name, deployment_name)
      @job_manager = job_manager
      @logger = logger
      @name = name
      @deployment_name = deployment_name
    end

    def with_updated_instances(instance_group, keep_alive, &blk)
      instance_name = instance_group.instances.first.model.name

      begin
        update_instances
        parent_id = add_event(instance_name)
        block_result = blk.call
        add_event(instance_name, parent_id, block_result.exit_code)
      rescue Exception => e
        add_event(instance_name, parent_id, nil, e)
        cleanup_vms_and_log_error(keep_alive)
        raise
      else
        cleanup_vms( keep_alive)
        return block_result
      end
    end

    def ignore_cancellation?
      @ignore_cancellation
    end

    private

    def update_instances
      @logger.info('Starting to create missing vms')
      @job_manager.create_missing_vms

      @logger.info('Starting to update job instances')
      @job_manager.update_instances
    end

    def cleanup_vms_and_log_error(keep_alive)
      begin
        cleanup_vms(keep_alive)
      rescue Exception => e
        @logger.warn("Failed to delete vms: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    def cleanup_vms(keep_alive)
      if keep_alive
        @logger.info('Skipping vms deletion, keep-alive is set')
      else
        @logger.info('Deleting vms')
        delete_vms
      end
    end

    def delete_vms
      @ignore_cancellation = true

      @logger.info('Starting to delete job vms')
      @job_manager.delete_vms

      @ignore_cancellation = false
    end

    def add_event(instance_name, parent_id = nil, exit_code = nil, error = nil)
      context = exit_code.nil? ? {} : {exit_code: exit_code}
      event = Config.current_job.event_manager.create_event(
        {
          parent_id: parent_id,
          user: Config.current_job.username,
          action: 'run',
          object_type: 'errand',
          object_name: @name,
          task: Config.current_job.task_id,
          deployment: @deployment_name,
          instance: instance_name,
          error: error,
          context: context,
        })
      event.id
    end
  end
end
