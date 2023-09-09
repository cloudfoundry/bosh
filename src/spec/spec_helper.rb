require File.expand_path('shared/spec_helper', __dir__)

require 'fileutils'
require 'digest/sha1'
require 'tmpdir'
require 'tempfile'
require 'set'
require 'yaml'
require 'nats/io/client'
require 'restclient'
require 'bosh/director'
require 'blue-shell'
require 'bosh/dev/postgres_version'

Dir.glob(File.expand_path('support/**/*.rb', __dir__)).each { |f| require(f) }

ASSETS_DIR = File.expand_path('assets', __dir__)
TEST_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'test_release_template')
LINKS_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'links_releases', 'links_release_template')
MULTIDISK_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'multidisks_releases', 'multidisks_release_template')
FAKE_ERRAND_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'fake_errand_release_template')
BOSH_WORK_TEMPLATE = File.join(ASSETS_DIR, 'bosh_work_dir')

STDOUT.sync = true

module Bosh
  module Spec; end
end

RSpec.configure do |c|
  c.filter_run focus: true if ENV['FOCUS']
  c.filter_run_excluding db: :postgresql unless ENV['DB'] == 'postgresql'
  c.include BlueShell::Matchers

  c.before(:suite) do
    agent_dir = File.expand_path('../go/src/github.com/cloudfoundry/bosh-agent', __dir__)
    unless File.exist?("#{agent_dir}/out/bosh-agent") || ENV['TEST_ENV_NUMBER']
      puts "Building agent in #{agent_dir}..."

      raise 'Bosh agent build failed' unless system("#{agent_dir}/bin/build")
    end

    if ENV['DB'] == 'postgresql'
      local_major_and_minor_version = Bosh::Dev::PostgresVersion.local_version.split('.')[0]
      release_major_and_minor_version = Bosh::Dev::PostgresVersion.release_version.split('.')[0]
      unless local_major_and_minor_version == release_major_and_minor_version
        raise "Postgres version mismatch: release version is #{release_major_and_minor_version};" \
          " local version is #{local_major_and_minor_version}."
      end
    end
  end
end

BlueShell.timeout = 180 # the cli can be pretty slow
