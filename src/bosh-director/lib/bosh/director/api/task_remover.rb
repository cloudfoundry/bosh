module Bosh::Director::Api
  class TaskRemover
    def initialize(max_tasks)
      @max_tasks = max_tasks
    end

    def remove(type, count = 10)
      removal_candidates_dataset(type, count).paged_each do |task|
        remove_task(task)
      end
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

    def removal_candidates_dataset(type, count)
      Bosh::Director::Models::Task.filter(Sequel.lit("state NOT IN ('processing', 'queued') and type='#{type}'")).
        select(:id, :output).order { Sequel.desc(:id) }.limit(count, @max_tasks)
    end
  end
end
