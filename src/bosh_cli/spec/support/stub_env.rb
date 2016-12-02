RSpec.configure do |config|
  config.before do
    stub_const('ENV', {})
  end
end
