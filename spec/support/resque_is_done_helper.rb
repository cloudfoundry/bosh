RSpec.configure do |config|
  config.after(type: :integration) do
    unless current_sandbox.director_service.resque_is_done?
      fail 'Resque is still running'
    end
  end
end
