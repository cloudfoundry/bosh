require 'bosh/director/api/task_helper'

module Bosh::Director

  # Abstracts the delayed jobs system.

  class JobQueue
    def enqueue(username, job_class, description, params, deployment_name = nil)
      task = Api::TaskHelper.new.create_task(username, job_class.job_type, description, deployment_name)

      Delayed::Worker.backend = :sequel
      db_job = Bosh::Director::Jobs::DBJob.new(job_class, task.id, params)
      Delayed::Job.enqueue db_job

      task
    end
  end
end
