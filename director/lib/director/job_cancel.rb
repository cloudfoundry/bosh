module Bosh::Director
  class JobCancel

    def initialize(task_id)
      @task_id = task_id
      @logger = Config.logger
    end

    def cancel?
      task = Models::Task[@task_id]
      if task.state == "cancelling"
        raise TaskCancelled.new(@task_id)
      end
    end
  end
end

