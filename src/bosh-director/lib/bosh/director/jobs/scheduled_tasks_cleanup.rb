require 'date'

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
        failed_cleaning = []
        Bosh::Director::Models::Task.select.where('state': %w[queued processing]).each do |task|
          next if actual_delayed_job_scheduled_task_ids.include?(task.id)

          # Newly created tasks are first created in the tasks db, then in the delayed jobs db.
          # So if a task is being created while we get the list of all jobs in the delayed jobs table,
          # we may end up missing an item.
          # To avoid cleaning up tasks where the delayed job item doesn't exist yet, we only clean tasks
          # if the timestamp older than 5 minutes.
          next unless (DateTime.now.to_time.to_i - task.timestamp.to_i) >= 300

          errored_tasks << task.id
          task.state = 'error'
          failed_cleaning << errored_tasks.pop if task.save.nil?
        end

        return result if errored_tasks.empty?

        unless failed_cleaning.empty?
          Bosh::Director::Config.logger.debug("There were issues updating task ids: #{failed_cleaning}.
                                               These will be retried on the next cleanup")
        end

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
