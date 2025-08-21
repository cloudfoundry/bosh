module Bosh::Director
  # Coordinates the safe deletion of an instance and all associates resources.
  class DiskDeleter
    def initialize(logger, disk_manager, options = {})
      @disk_manager = disk_manager
      force = options.fetch(:force, false)
      @error_ignorer = ErrorIgnorer.new(force, @logger)
    end

    def delete_dynamic_disks(deployment_model, event_log_stage, options = {})
      max_threads = options[:max_threads] || Config.max_threads
      ThreadPool.new(:max_threads => max_threads).wrap do |pool|
        deployment_model.dynamic_disks.each do |dynamic_disk|
          pool.process { delete_dynamic_disk(dynamic_disk, event_log_stage) }
        end
      end
    end

    private

    def delete_dynamic_disk(dynamic_disk, event_log_stage)
      parent_id = add_event(dynamic_disk.deployment.name, dynamic_disk.name)
      event_log_stage.advance_and_track(dynamic_disk.to_s) do
        @error_ignorer.with_force_check do
          @disk_manager.delete_dynamic_disk(dynamic_disk)
        end

        dynamic_disk.destroy
      end
    rescue Exception => e
      raise e
    ensure
      add_event(deployment_name, dynamic_disk.name, parent_id, e) if parent_id
    end

    def add_event(deployment_name, disk_name, parent_id = nil, error = nil)
      event = Config.current_job.event_manager.create_event(
        parent_id:   parent_id,
        user:        Config.current_job.username,
        action:      'delete',
        object_type: 'disk',
        object_name: disk_name,
        task:        Config.current_job.task_id,
        deployment:  deployment_name,
        error:       error,
      )
      event.id
    end
  end
end
