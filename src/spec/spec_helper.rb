SPEC_ROOT = File.dirname(__FILE__)

require File.expand_path('shared/spec_helper', SPEC_ROOT)

require 'bosh/director'
require 'nats/io/client'

require 'fileutils'
require 'digest/sha1'
require 'tmpdir'
require 'tempfile'
require 'yaml'
require 'restclient'

require 'blue-shell'

require 'bosh/dev/sandbox/postgres_version'

Dir.glob(File.join(SPEC_ROOT, 'support/**/*.rb')).each { |f| require(f) }

ASSETS_DIR = File.join(SPEC_ROOT, 'assets')
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
  c.expect_with :rspec do |expect|
    expect.max_formatted_output_length = 10_000
  end
  c.filter_run focus: true if ENV['FOCUS']
  c.filter_run_excluding db: :postgresql unless ENV['DB'] == 'postgresql'
  c.include BlueShell::Matchers

  c.before(:suite) do
    agent_dir = File.expand_path('../go/src/github.com/cloudfoundry/bosh-agent', __dir__)
    unless File.exist?("#{agent_dir}/out/bosh-agent") || ENV['TEST_ENV_NUMBER']
      puts "Building agent in #{agent_dir}..."

      raise 'Bosh agent build failed' unless system("#{agent_dir}/bin/build")
    end

    Bosh::Dev::Sandbox::PostgresVersion.ensure_version_match!(ENV['DB'])
  end
end

BlueShell.timeout = 180 # the cli can be pretty slow
