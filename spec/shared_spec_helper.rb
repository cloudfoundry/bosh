# This file is included by every sub-project's spec_helper

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
