# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class BaseJob

      def self.perform(task_id, *args)
        Bosh::Director::JobRunner.new(self, task_id).run(*args)
      end

      attr_accessor :task_id

      def initialize(*args)
        @logger = Config.logger
        @event_log = Config.event_log
        @result_file = Config.result
      end

      def task_cancelled?
        task = Models::Task[@task_id]
        task && (task.state == "cancelling" || task.state == "timeout")
      end

      def task_checkpoint
        raise TaskCancelled.new(@task_id) if task_cancelled?
      end

      def begin_stage(stage_name, n_steps)
        @event_log.begin_stage(stage_name, n_steps)
        @logger.info(stage_name)
      end

      def track_and_log(task)
        @event_log.track(task) do |ticker|
          @logger.info(task)
          yield ticker if block_given?
        end
      end

    end
  end
end
