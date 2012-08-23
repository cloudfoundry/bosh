# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class BaseJob

      def self.perform(task_id, *args)
        Bosh::Director::JobRunner.new(self, task_id).run(*args)
      end

      attr_accessor :task_id

      attr_reader :logger
      attr_reader :event_log
      attr_reader :result_file

      def initialize(*args)
        @logger = Config.logger
        @event_log = Config.event_log
        @result_file = Config.result
        @task_manager = Api::TaskManager.new
        @task_id = nil
      end

      # @return [Boolean] Has task been cancelled?
      def task_cancelled?
        return false if @task_id.nil?
        task = @task_manager.find_task(@task_id)
        task && (task.state == "cancelling" || task.state == "timeout")
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
    end
  end
end
