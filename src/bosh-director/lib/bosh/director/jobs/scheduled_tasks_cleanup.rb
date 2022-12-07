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

      def update_orphaned_tasks_with_state_error(result)
        actual_delayed_job_scheduled_task_ids = []
        Delayed::Worker.backend = :sequel
        Delayed::Job.all.select do |job|
          actual_delayed_job_scheduled_task_ids << YAML.safe_load(job.handler)['task_id']
        end

        errored_tasks = []
        Bosh::Director::Models::Task.select.where('state': %w[queued processing]).each do |task|
          next if actual_delayed_job_scheduled_task_ids.include?(task.id)

          errored_tasks << task.id
          task.state = 'error'
          task.save
        end

        return result if errored_tasks.empty?

        result << "Marked orphaned tasks with ids: #{errored_tasks} as errored. They do not have a worker job backing them"
      end

      def perform
        result = "Deleted tasks and logs for\n"

        task_types.each do |type|
          tasks_removed = @task_remover.remove(type)
          result << "#{tasks_removed} task(s) of type '#{type}'\n"
        end

        update_orphaned_tasks_with_state_error result
      end

      def task_types
        Bosh::Director::Models::Task.select(:type).where(state: 'done').group(:type).map { |grouping| grouping[:type] }.sort
      end
    end
  end
end
