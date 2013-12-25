require 'bosh/director/api/task_helper'

module Bosh::Director

  # Abstracts the resque system.

  class JobQueue
    def enqueue(user, job_class, description, params)
      task = Api::TaskHelper.new.create_task(user, job_class.job_type, description)

      Resque.enqueue(job_class, task.id, *params)

      task
    end
  end
end
