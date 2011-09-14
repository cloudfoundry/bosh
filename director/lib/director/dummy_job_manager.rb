module Bosh::Director

  class DummyJobManager
    include TaskHelper

    def run_dummy_job(user)
      task = create_task(user, "dummy job")
      Resque.enqueue(Jobs::DummyJob, task.id, nil)
      task
    end
  end
end
