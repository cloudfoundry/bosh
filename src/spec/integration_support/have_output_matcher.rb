require 'blue-shell'

module IntegrationSupport
  module HaveOutputMatcher
    def have_output(expected_code)
      BlueShell.timeout = 180 # the cli can be pretty slow
      BlueShell::Matchers::OutputMatcher.new(expected_code)
    end
  end
end

RSpec.configure do |c|
  c.include(IntegrationSupport::HaveOutputMatcher)
end
