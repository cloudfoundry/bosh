# Copyright (c) 2009-2012 VMware, Inc.

require 'rspec'

ENV['RACK_ENV'] = 'test'

require 'bosh_agent'
require 'timecop'
require 'fakefs/spec_helpers'

Dir.glob(File.expand_path('support/**/*.rb', File.dirname(__FILE__))).each do |support|
  require support
end

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
