module Bosh::Director::Api
  class TaskRemover
    def initialize(max_tasks)
      @max_tasks = max_tasks
    end

    def remove(type)
      tasks_removed = 0
      removal_candidates_dataset(type).paged_each(strategy: :filter, stream: false) do |task|
        tasks_removed += 1
        remove_task(task)
      end
      tasks_removed
    end

    def remove_task(task)
      FileUtils.rm_rf(task.output) if task.output

      begin
        task.destroy
      rescue Sequel::NoExistingObject
        # it's possible for multiple threads to initiate task removal
        # both could get the same results from removal_candidates_dataset,
        # but only the first would succeed at deletion; ignore failure of
        # subsequent attempts
        Bosh::Director::Config.logger.debug("TaskRemover: Sequel::NoExistingObject, attempting to remove #{task}.")
      end
    end

    private

    def removal_candidates_dataset(type)
      base_filter = Bosh::Director::Models::Task.where(type: type)
        .exclude(state: %w[processing queued])
        .select(:id, :output).order { Sequel.desc(:id) }

      starting_id = base_filter.limit(1, @max_tasks).first&.id || 0

      base_filter.where { id <= starting_id }
    end
  end
end
