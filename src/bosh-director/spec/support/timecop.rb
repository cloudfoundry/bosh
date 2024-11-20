require 'timecop'

RSpec.configure do |config|
  config.after(:each) { Timecop.return }
end