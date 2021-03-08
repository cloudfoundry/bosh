module Bosh::Director
  module Jobs
    class ScheduledTasksCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_task_cleanup
      end

      def self.schedule_message
        'clean up tasks'
      end

      def initialize(_param = {})
        @task_remover = Bosh::Director::Api::TaskRemover.new(Config.max_tasks)
      end

      def perform
        result = "Deleted tasks and logs for\n"

        task_types.each do |type|
          tasks_removed = @task_remover.remove(type)
          result << "#{tasks_removed} task(s) of type '#{type}'\n"
        end

        result
      end

      def task_types
        Bosh::Director::Models::Task.select(:type).where(state: 'done').group(:type).map { |grouping| grouping[:type] }.sort
      end
    end
  end
end
