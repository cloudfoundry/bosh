# Copyright (c) 2009-2012 VMware, Inc.

require 'rspec'

ENV['RACK_ENV'] = 'test'

require 'bosh_agent'
require 'digest/sha1'
require 'fileutils'
require 'zlib'
require 'httpclient'
require 'timecop'

Dir.glob(File.expand_path('support/**/*.rb', File.dirname(__FILE__))).each do |support|
  require support
end

RSpec.configure do |config|
  config.include Bosh::Agent::Spec::Assets
  config.include Bosh::Agent::Spec::UglyHelpers

  config.before do
    Bosh::Agent::Config.clear
    Bosh::Agent::Config.logger = Logger.new(StringIO.new)
    setup_directories
    Bosh::Agent::Monit.enabled = false
  end

  config.before(dummy_infrastructure: true) do
    Bosh::Agent::Config.infrastructure_name = 'dummy'
  end
end
