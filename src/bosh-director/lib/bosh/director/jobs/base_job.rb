module Bosh::Director
  module Jobs
    class BaseJob
      def self.job_type
        raise NotImplementedError, 'Subclasses must return a symbol representing type'
      end

      def self.perform(task_id, worker_name, *args)
        Bosh::Director::JobRunner.new(self, task_id, worker_name).run(*args)
      end

      def self.schedule_message
        "scheduled #{name.split('::').last}"
      end

      attr_accessor :task_id

      def logger
        @logger ||= Config.logger
      end

      def task_result
        @task_result ||= Config.result
      end

      def dry_run?
        false
      end

      # @return [Boolean] Has task been cancelled?
      def task_cancelled?
        return false if task_id.nil?

        task = task_manager.find_task(task_id)
        task && (task.state == 'cancelling' || task.state == 'timeout' || task.state == 'cancelled')
      end

      def task_checkpoint
        raise TaskCancelled, "Task #{task_id} cancelled" if task_cancelled?
      end

      def begin_stage(stage_name, n_steps = nil)
        @event_log_stage = Config.event_log.begin_stage(stage_name, n_steps)
        logger.info(stage_name)
      end

      def track_and_log(task, log = true)
        @event_log_stage.advance_and_track(task) do |ticker|
          logger.info(task) if log
          yield ticker if block_given?
        end
      end

      def single_step_stage(stage_name)
        begin_stage(stage_name, 1)
        track_and_log(stage_name, false) { yield }
      end

      def username
        @user ||= task_manager.find_task(task_id).username
      end

      def event_manager
        @event_manager ||= Api::EventManager.new(Config.record_events)
      end

      private

      def task_manager
        @task_manager ||= Api::TaskManager.new
      end
    end
  end
end
