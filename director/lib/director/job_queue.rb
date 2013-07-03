module Bosh::Director

  # Abstracts the resque system.

  class JobQueue
    include Api::TaskHelper

    def enqueue(job_class, description, user_name, params)
      task = create_task(user_name, job_class.job_type, description)
      Resque.enqueue(job_class, task.id, *params)

      task
    end
  end
end
