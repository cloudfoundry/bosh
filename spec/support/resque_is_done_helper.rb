RSpec.configure do |config|
  config.after(type: :integration) do
    unless current_sandbox.director_service.resque_is_done?
      current_sandbox.director_service.print_current_tasks
      fail 'Resque is still running'
    end
  end
end
