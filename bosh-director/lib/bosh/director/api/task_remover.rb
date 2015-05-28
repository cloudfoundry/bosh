module Bosh::Director::Api
  class TaskRemover
    def initialize(max_tasks)
      @max_tasks = max_tasks
    end

    def remove
      removal_candidates_dataset.each do |task|
        FileUtils.rm_rf(task.output) if task.output
        task.destroy
      end
    end

    private
    def removal_candidates_dataset
      Bosh::Director::Models::Task.filter("state NOT IN ('processing', 'queued')").
        order{id.desc}.limit(2, @max_tasks)
    end
  end
end
