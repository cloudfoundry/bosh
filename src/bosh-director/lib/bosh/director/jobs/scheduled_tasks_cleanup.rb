module Bosh::Director
  module Jobs
    class ScheduledTasksCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_task_cleanup
      end

      def self.has_work(_)
        type_counts_to_delete.count.positive?
      end

      def self.schedule_message
        'clean up tasks'
      end

      def initialize(_params)
        @task_remover = Bosh::Director::Api::TaskRemover.new(Config.max_tasks)
      end

      def perform
        result = "Deleted tasks and logs for\n"

        ScheduledTasksCleanup.type_counts_to_delete.each do |t|
          @task_remover.remove(t[:type], t[:count])
          result << "#{t[:count]} task(s) of type '#{t[:type]}'\n"
        end

        result
      end

      def self.type_counts_to_delete
        max_tasks = Config.max_tasks
        counts_by_type
          .map { |t| { type: t[:type], count: [0, t[:count] - max_tasks].max } }
          .select { |g| (g[:count]).positive? }
      end

      def self.counts_by_type
        Bosh::Director::Models::Task.where(state: 'done').group_and_count(:type).all
      end
    end
  end
end
