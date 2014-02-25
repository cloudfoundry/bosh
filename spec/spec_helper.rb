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
  module Spec; end
end

RSpec.configure do |c|
  c.filter_run :focus => true if ENV["FOCUS"]
end
