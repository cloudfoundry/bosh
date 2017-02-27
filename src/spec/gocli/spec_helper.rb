require File.expand_path('../../shared/spec_helper', __FILE__)

require 'fileutils'
require 'digest/sha1'
require 'tmpdir'
require 'tempfile'
require 'set'
require 'yaml'
require 'nats/client'
require 'restclient'
require 'bosh/director'
require 'blue-shell'
require_relative '../../bosh-dev/lib/bosh/dev/postgres_version'

Dir.glob(File.expand_path('../../support/**/*.rb', __FILE__)).each { |f| require(f) }
Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }
Dir.glob(File.expand_path('../shared/support/**/*.rb', __FILE__)).each { |f| require(f) }

STDOUT.sync = true

module Bosh
  module Spec; end
end

RSpec.configure do |c|
  c.filter_run :focus => true if ENV['FOCUS']
  c.filter_run_excluding :db => :postgresql unless ENV['DB'] == 'postgresql'
  c.include BlueShell::Matchers
  c.full_backtrace = true
  c.before(:suite) do
    unless ENV['TEST_ENV_NUMBER']
      agent_build_cmd = File.expand_path('../../../go/src/github.com/cloudfoundry/bosh-agent/bin/build', __FILE__)
      unless system(agent_build_cmd)
        raise 'Bosh agent build failed'
      end

      gnatsd_build_cmd = File.expand_path('../../../go/src/github.com/nats-io/gnatsd/bin/build', __FILE__)
      unless system(gnatsd_build_cmd)
        raise 'gnatsd build failed'
      end
    end

    if ENV['DB'] == 'postgresql'
      local_major_and_minor_version = Bosh::Dev::PostgresVersion.local_version.split('.')[0..1]
      release_major_and_minor_version = Bosh::Dev::PostgresVersion.release_version.split('.')[0..1]
      unless local_major_and_minor_version == release_major_and_minor_version
        raise "Postgres version mismatch: release version is #{release_major_and_minor_version}; local version is #{local_major_and_minor_version}"
      end
    end
  end
end

BlueShell.timeout = 180 # the cli can be pretty slow
