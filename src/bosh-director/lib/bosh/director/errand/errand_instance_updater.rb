module Bosh::Director
  class Errand::ErrandInstanceUpdater
    def initialize(instance_group_manager, logger, errand_name, deployment_name)
      @instance_group_manager = instance_group_manager
      @logger = logger
      @errand_name = errand_name
      @deployment_name = deployment_name
      @ignore_cancellation = false
    end

    def with_updated_instances(keep_alive, &blk)

      begin
        @logger.info('Starting to update job instances')
        @instance_group_manager.update_instances

        block_result = blk.call
      rescue Exception => e
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
  end
end
