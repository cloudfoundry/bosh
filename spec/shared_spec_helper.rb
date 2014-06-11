# This file is included by every sub-project's spec_helper

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    root          File.expand_path('../..', __FILE__)
    merge_timeout 3600
    # command name is injected by the spec.rake runner
    if ENV['BOSH_BUILD_NAME']
      command_name ENV['BOSH_BUILD_NAME']
    end
  end
end

require 'rspec'
RSpec.configure do |config|
  config.deprecation_stream = StringIO.new

  config.mock_with :rspec do |mocks|
    # Turn on after fixing several specs that stub out private methods
    # mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end
end

# It must stay minimal!
