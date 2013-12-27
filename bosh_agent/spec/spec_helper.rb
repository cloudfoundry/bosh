require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

ENV['RACK_ENV'] = 'test'

require 'bosh_agent'
require 'timecop'
require 'fakefs/spec_helpers'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }

RSpec.configure do |config|
  config.include Bosh::Agent::Spec::Assets
  config.include Bosh::Agent::Spec::UglyHelpers

  config.before do
    Bosh::Agent::Config.should be_a(Bosh::Agent::Configuration)
    stub_const('Bosh::Agent::Config', Bosh::Agent::Configuration.new)

    Bosh::Agent::Config.logger = Logger.new(StringIO.new)
    setup_directories
    Bosh::Agent::Monit.enabled = false
  end

  config.before(dummy_infrastructure: true) do
    Bosh::Agent::Config.infrastructure_name = 'dummy'
  end
end
