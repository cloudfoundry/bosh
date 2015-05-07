require File.expand_path('../shared_spec_helper', __FILE__)

require 'fileutils'
require 'digest/sha1'
require 'tmpdir'
require 'tempfile'
require 'set'
require 'yaml'
require 'nats/client'
require 'redis'
require 'restclient'
require 'bosh/director'
require 'blue-shell'

SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
Dir.glob("#{SPEC_ROOT}/support/**/*.rb") { |f| require(f) }

ASSETS_DIR = File.join(SPEC_ROOT, 'assets')
TEST_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'test_release_template')
BOSH_WORK_TEMPLATE    = File.join(ASSETS_DIR, 'bosh_work_dir')

STDOUT.sync = true

module Bosh
  module Spec; end
end

RSpec.configure do |c|
  c.filter_run :focus => true if ENV['FOCUS']
  c.filter_run_excluding :db => :postgresql unless ENV['DB'] == 'postgresql'
  c.include BlueShell::Matchers
  c.before(:suite) do
    unless ENV['TEST_ENV_NUMBER']
      agent_build_cmd = File.expand_path('../../go/src/github.com/cloudfoundry/bosh-agent/bin/build', __FILE__)
      system(agent_build_cmd)
    end
  end
end

BlueShell.timeout = 180 # the cli can be pretty slow
