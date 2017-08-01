module Bosh::Director
  class Errand::ErrandInstanceUpdater
    def initialize(instance_group_manager, logger, errand_name, deployment_name)
      @instance_group_manager = instance_group_manager
      @logger = logger
      @errand_name = errand_name
      @deployment_name = deployment_name
      @ignore_cancellation = false
    end

    def with_updated_instances(instance_name, keep_alive, &blk)
      begin
        @logger.info('Starting to update job instances')
        @instance_group_manager.update_instances

        parent_id = add_event(instance_name)
        block_result = blk.call
        add_event(instance_name, parent_id, block_result.exit_code)
      rescue Exception => e
        add_event(instance_name, parent_id, nil, e)
        cleanup_vms_and_log_error(keep_alive)
        raise
      else
        cleanup_vms(keep_alive)
        return block_result
      end
    end

    def create_vms(keep_alive)
      begin
        @logger.info('Starting to create missing vms')
        @instance_group_manager.create_missing_vms
      rescue Exception => e
        cleanup_vms_and_log_error(keep_alive)
        raise
      end
    end

    def ignore_cancellation?
      @ignore_cancellation
    end

    private

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
      @instance_group_manager.delete_vms

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
          object_name: @errand_name,
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
