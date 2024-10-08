module Support
  module FakeJob
    def fake_job
      Bosh::Director::Config.current_job = Bosh::Director::Jobs::BaseJob.new
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FakeJob)
end
