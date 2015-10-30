module Bosh::Director
  module Jobs
    class BaseJob

      def self.job_type
        raise NotImplementedError.new('Subclasses must return a symbol representing type')
      end

      def self.perform(task_id, *args)
        Bosh::Director::JobRunner.new(self, task_id).run(*args)
      end

      attr_accessor :task_id

      def logger
        @logger ||= Config.logger
      end

      def event_log
        @event_log ||= Config.event_log
      end

      def result_file
        @result_file ||= Config.result
      end

      # @return [Boolean] Has task been cancelled?
      def task_cancelled?
        return false if task_id.nil?
        task = task_manager.find_task(task_id)
        task && (task.state == 'cancelling' || task.state == 'timeout' || task.state == 'cancelled')
      end

      def task_checkpoint
        if task_cancelled?
          raise TaskCancelled, "Task #{task_id} cancelled"
        end
      end

      def begin_stage(stage_name, n_steps)
        event_log.begin_stage(stage_name, n_steps)
        logger.info(stage_name)
      end

      def track_and_log(task, log = true)
        event_log.track(task) do |ticker|
          logger.info(task) if log
          yield ticker if block_given?
        end
      end

      def single_step_stage(stage_name)
        begin_stage(stage_name, 1)
        track_and_log(stage_name, false) { yield }
      end

      private

      def task_manager
        @task_manager ||= Api::TaskManager.new
      end
    end
  end
end
