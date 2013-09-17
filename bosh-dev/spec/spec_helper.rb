require 'rspec'
require 'rake'
require 'rspec/fire'
require 'fakefs/spec_helpers'
require 'webmock/rspec'

Dir.glob(File.expand_path('support/**/*.rb', File.dirname(__FILE__))).each do |support|
  require support
end

SPEC_ROOT = File.dirname(__FILE__)

def spec_asset(name)
  File.join(SPEC_ROOT, 'assets', name)
end

RSpec.configure do |config|
  config.include(RSpec::Fire)
end

RSpec::Fire.configure do |config|
  config.verify_constant_names = true
end
