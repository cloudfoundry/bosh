SPEC_ROOT = File.dirname(__FILE__)

$LOAD_PATH << File.expand_path(SPEC_ROOT)

require 'shared/spec_helper'
require 'rspec/core/formatters/console_codes'

require 'fileutils'
require 'digest/sha1'
require 'tmpdir'
require 'tempfile'
require 'yaml'
require 'restclient'

require 'bosh/director'
require 'nats/client'
require 'nats/io/client'

Dir.glob(File.join(SPEC_ROOT, 'integration_support/**/*.rb')).each { |f| require(f) }
Dir.glob(File.join(SPEC_ROOT, 'support/**/*.rb')).each { |f| require(f) }

ASSETS_DIR = File.join(SPEC_ROOT, 'assets')
TEST_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'test_release_template')
LINKS_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'links_releases', 'links_release_template')
MULTIDISK_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'multidisks_releases', 'multidisks_release_template')
FAKE_ERRAND_RELEASE_TEMPLATE = File.join(ASSETS_DIR, 'fake_errand_release_template')
BOSH_WORK_TEMPLATE = File.join(ASSETS_DIR, 'bosh_work_dir')

STDOUT.sync = true

RSpec.configure do |c|
  c.expect_with :rspec do |expect|
    expect.max_formatted_output_length = 10_000
  end
  c.filter_run focus: true if ENV['FOCUS']

  unless ENV['DB'] == 'postgresql'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap('Skipping postgresql-only tests', :yellow)
    c.filter_run_excluding db: :postgresql
  end

  if ENV['DEFAULT_UPDATE_VM_STRATEGY'] == 'create-swap-delete'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap('Skipping non-create-swap-delete tests', :yellow)
    c.filter_run_excluding no_create_swap_delete: true
  else
    puts RSpec::Core::Formatters::ConsoleCodes.wrap('Skipping create-swap-delete tests', :yellow)
    c.filter_run_excluding create_swap_delete: true
  end

  if ENV['SKIP_RUN_SCRIPT_ENV'] == 'true'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap('Skipping tests using env params to run_script', :yellow)
    c.filter_run_excluding run_script_env: true
  end

  c.after(type: :integration) do
    current_sandbox.director_service.wait_for_tasks_to_finish
  end
end
