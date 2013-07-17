require 'rspec'
require 'rake'
require 'rspec/fire'

SPEC_ROOT = File.dirname(__FILE__)

def spec_asset(name)
  File.join(SPEC_ROOT, 'assets', name)
end

RSpec.configure do |config|
  config.include(RSpec::Fire)
end
