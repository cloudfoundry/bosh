require 'spec_helper'

require 'yaml'
require 'bat/stemcell'
require 'bat/release'
require 'bat/deployment'
require 'fileutils'

require 'tempfile'
require 'common/exec'
require 'resolv'

ASSETS_DIR = File.join(SPEC_ROOT, 'system', 'assets')
BAT_RELEASE_DIR = File.join(ASSETS_DIR, 'bat-release')

Dir.glob(File.join(File.expand_path(File.dirname(__FILE__)), 'helpers', '*_helper.rb')).each do |helper|
  require File.expand_path(helper)
end

RSpec.configure do |config|
  config.include(BoshHelper)
  config.include(DeploymentHelper)

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # bosh helper isn't available, so it has to be rolled by hand
  config.before(:suite) do
    director = BoshHelper.read_environment('BAT_DIRECTOR')
    director.should_not be_nil

    output = %x{bosh --config #{BoshHelper.bosh_cli_config_path} --user admin --password admin target #{director} 2>&1}
    output.should match /Target \w*\s*set/
    $?.exitstatus.should == 0
  end

  config.after(:suite) do
    BoshHelper.delete_bosh_cli_config
  end

  config.before(:each) do
    requirement :no_tasks_processing unless example.metadata[:skip_task_check]
  end
end

RSpec::Matchers.define :succeed do |expected|
  match do |actual|
    actual.exit_status == 0
  end
end

RSpec::Matchers.define :succeed_with do |expected|
  match do |actual|
    if actual.exit_status != 0
      false
    elsif expected.instance_of?(String)
      actual.output == expected
    elsif expected.instance_of?(Regexp)
      !!actual.output.match(expected)
    else
      raise ArgumentError, "don't know what to do with a #{expected.class}"
    end
  end
  failure_message_for_should do |actual|
    if expected.instance_of?(Regexp)
      what = 'match'
      exp = "/#{expected.source}/"
    else
      what = 'be'
      exp = expected
    end
    "expected\n#{actual.output}to #{what}\n#{exp}"
  end
end
