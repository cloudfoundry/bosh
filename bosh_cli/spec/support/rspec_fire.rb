require 'rspec/fire'

RSpec.configure do |config|
  config.include(RSpec::Fire)
end

RSpec::Fire.configure do |config|
  config.verify_constant_names = true
end
