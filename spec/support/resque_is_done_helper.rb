RSpec.configure do |config|
  config.after(type: :integration) do
    current_sandbox.director_service.wait_for_tasks_to_finish
  end
end
