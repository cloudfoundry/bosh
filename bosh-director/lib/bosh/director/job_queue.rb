module Bosh::Director

  # Abstracts the resque system.

  class JobQueue
    include Api::TaskHelper

    def enqueue(user, job_class, description, params)
      task = create_task(user, job_class.job_type, description)

      Resque.enqueue(job_class, task.id, *params)

      task
    end
  end
end
