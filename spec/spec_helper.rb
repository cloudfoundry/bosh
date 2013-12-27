require File.expand_path('../shared_spec_helper', __FILE__)

require "fileutils"
require "digest/sha1"
require "tmpdir"
require "tempfile"
require "set"
require "yaml"
require "nats/client"
require "redis"
require "restclient"
require "bosh/director"

SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
Dir.glob("#{SPEC_ROOT}/support/**/*.rb") { |f| require(f) }

SANDBOX_DIR = Dir.mktmpdir
TEST_RELEASE_DIR = File.join(SANDBOX_DIR, "test_release")
BOSH_WORK_DIR    = File.join(SANDBOX_DIR, "bosh_work_dir")
BOSH_CONFIG      = File.join(SANDBOX_DIR, "bosh_config.yml")

ASSETS_DIR = File.join(SPEC_ROOT, "assets")
TEST_RELEASE_TEMPLATE = File.join(ASSETS_DIR, "test_release_template")
BOSH_WORK_TEMPLATE    = File.join(ASSETS_DIR, "bosh_work_dir")

STDOUT.sync = true

module Bosh
  module Spec
    module IntegrationTest
      class CliUsage; end
      class HealthMonitor; end
      class DirectorScheduler; end
    end
  end
end

RSpec.configure do |c|
  c.before do |example|
    cleanup_bosh
    setup_test_release_dir
    setup_bosh_work_dir
  end

  c.filter_run :focus => true if ENV["FOCUS"]
end

def spec_asset(name)
  File.expand_path("../assets/#{name}", __FILE__)
end

def yaml_file(name, object)
  f = Tempfile.new(name)
  f.write(Psych.dump(object))
  f.close
  f
end

def setup_bosh_work_dir
  FileUtils.cp_r(BOSH_WORK_TEMPLATE, BOSH_WORK_DIR, :preserve => true)
end

def setup_test_release_dir
  FileUtils.cp_r(TEST_RELEASE_TEMPLATE, TEST_RELEASE_DIR, :preserve => true)
  Dir.chdir(TEST_RELEASE_DIR) do
    ignore = %w(r
        blobs
        dev-releases
        config/dev.yml
        config/private.yml
        releases/*.tgz
        dev_releases
        .dev_builds
        .final_builds/jobs/**/*.tgz
        .final_builds/packages/**/*.tgz
        blobs
        .blobs
    )
    File.open('.gitignore', 'w+') do |f|
      f.write(ignore.join("\n") + "\n")
    end
    `git init;
     git config user.name "John Doe";
     git config user.email "john.doe@example.org";
     git add .;
     git commit -m "Initial Test Commit"`
  end
end

def cleanup_bosh
  FileUtils.rm_rf(SANDBOX_DIR)
  FileUtils.mkdir_p(SANDBOX_DIR)
end
