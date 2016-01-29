require 'bosh/director/api/task_helper'

module Bosh::Director

  # Abstracts the resque system.

  class JobQueue
    def enqueue(username, job_class, description, params)
      task = Api::TaskHelper.new.create_task(username, job_class.job_type, description)

      Resque.enqueue(job_class, task.id, *params)

      task
    end
  end
end
