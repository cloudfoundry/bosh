module Bosh::Director::Api
  class TaskRemover
    def initialize(max_tasks)
      @max_tasks = max_tasks
    end

    def remove (type)
      removal_candidates_dataset(type).each do |task|
        FileUtils.rm_rf(task.output) if task.output
        task.destroy
      end
    end

    private
    def removal_candidates_dataset(type)
      Bosh::Director::Models::Task.filter("state NOT IN ('processing', 'queued') and type='#{type}'").
        order{Sequel.desc(:id)}.limit(2, @max_tasks)
    end
  end
end
