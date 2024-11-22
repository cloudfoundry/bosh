require 'blue-shell'

BlueShell.timeout = 180 # the cli can be pretty slow

module IntegrationSupport
  module CustomBlueShellMatcher
    def have_output(expected_code)
      BlueShell::Matchers::OutputMatcher.new(expected_code)
    end
  end
end

RSpec.configure do |c|
  c.include(IntegrationSupport::CustomBlueShellMatcher)
end
