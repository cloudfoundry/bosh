# This file is included by every sub-project's spec_helper

if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  SimpleCov.configure do
    add_filter '/spec/'
    add_filter '/vendor/'
  end

  SimpleCov.start do
    root          File.expand_path('../..', __dir__)
    merge_timeout 3600
    # command name is injected by the spec.rake runner
    command_name ENV['BOSH_BUILD_NAME'] if ENV['BOSH_BUILD_NAME']
  end
end

require 'rspec'

# Useful to see that tests are using expected version of Ruby in CI
puts "Using #{RUBY_DESCRIPTION}"

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end
end

Dir.glob(File.expand_path('support/**/*.rb', __dir__)).each { |f| require(f) }
# It must stay minimal!
