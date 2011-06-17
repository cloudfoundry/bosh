require "fileutils"
require "digest/sha1"
require "tmpdir"
require "tempfile"
require "set"
require "yaml"
require "nats/client"
require "sandbox"
require "deployments"
require "redis"

TEST_RELEASE_DIR = File.expand_path("../assets/test_release", __FILE__)

DEV_RELEASES_DIR   = File.join(TEST_RELEASE_DIR, "dev_releases")
FINAL_RELEASES_DIR = File.join(TEST_RELEASE_DIR, "releases")

DEV_BUILDS_DIR   = File.join(TEST_RELEASE_DIR, ".dev_builds")
FINAL_BUILDS_DIR = File.join(TEST_RELEASE_DIR, ".final_builds")

ASSETS_DIR = File.expand_path("../assets", __FILE__)

CLOUD_DIR      = "/tmp/bosh_test_cloud"
CLI_DIR        = File.expand_path("../../cli", __FILE__)
BOSH_CACHE_DIR = Dir.mktmpdir
BOSH_WORK_DIR  = File.join(ASSETS_DIR, "bosh_work_dir")
BOSH_CONFIG    = File.join(ASSETS_DIR, "bosh_config.yml")

module Bosh
  module Spec
    module IntegrationTest
      class CliUsage; end
      class HealthMonitor; end
    end
  end
end

RSpec.configure do |c|
  c.before(:each) do |example|
    reset_sandbox(example)
    cleanup_bosh
  end

  c.filter_run :focus => true if ENV["FOCUS"]
end

def spec_asset(name)
  File.expand_path("../assets/#{name}", __FILE__)
end

def start_sandbox
  puts "Starting sandboxed environment for Bosh tests..."
  Bosh::Spec::Sandbox.start
end

def stop_sandbox
  puts "\nStopping sandboxed environment for Bosh tests..."
  Bosh::Spec::Sandbox.stop
  cleanup_bosh
end

def reset_sandbox(example)
  desc = example ? example.example.metadata[:description] : ""
  Bosh::Spec::Sandbox.reset(desc)
end

def yaml_file(name, object)
  f = Tempfile.new(name)
  f.write(YAML.dump(object))
  f.close
  f
end

def run_bosh(cmd, work_dir = nil)
  Dir.chdir(work_dir || BOSH_WORK_DIR) do
    ENV["BUNDLE_GEMFILE"] = "#{CLI_DIR}/Gemfile"
    `#{CLI_DIR}/bin/bosh --non-interactive --no-color --config #{BOSH_CONFIG} --cache-dir #{BOSH_CACHE_DIR} #{cmd}`
  end
end

def cleanup_bosh
  [
   CLOUD_DIR,
   DEV_RELEASES_DIR,
   FINAL_RELEASES_DIR,
   DEV_BUILDS_DIR,
   FINAL_BUILDS_DIR,
   BOSH_CACHE_DIR
  ].each do |dir|
    FileUtils.rm_rf(dir)
  end

  FileUtils.rm_rf(BOSH_CONFIG)
end

start_sandbox
at_exit { stop_sandbox }
