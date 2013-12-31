require 'spec_helper'

require 'yaml'
require 'fileutils'
require 'tempfile'
require 'resolv'

require 'common/exec'

require 'bat/stemcell'
require 'bat/release'
require 'bat/deployment'
require 'bat/bosh_helper'
require 'bat/deployment_helper'

ASSETS_DIR = File.join(SPEC_ROOT, 'system', 'assets')
BAT_RELEASE_DIR = File.join(ASSETS_DIR, 'bat-release')

RSpec.configure do |config|
  config.include(Bat::BoshHelper)
  config.include(Bat::DeploymentHelper)

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # bosh helper isn't available, so it has to be rolled by hand
  config.before(:suite) do
    director = Bat::BoshHelper.read_environment('BAT_DIRECTOR')
    director.should_not be_nil

    output = %x{bosh --config #{Bat::BoshHelper.bosh_cli_config_path} --user admin --password admin target #{director} 2>&1}
    output.should match /Target \w*\s*set/
    $?.exitstatus.should == 0
  end

  config.before do |example|
    unless example.metadata[:skip_task_check]
      requirement :no_tasks_processing
    end
  end
end

RSpec::Matchers.define :succeed do |_|
  match do |actual|
    expect(actual.exit_status).to eq 0
  end

  failure_message_for_should do |actual|
    'expected command to exit with 0 but was ' +
      "#{actual.exit_status}. output was\n#{actual.output}"
  end
end

RSpec::Matchers.define :succeed_with do |expected|
  match do |actual|
    expect(actual.exit_status).to eq 0

    case expected
      when String
        expect(actual.output).to eq(expected)
      when Regexp
        # See https://www.relishapp.com/rspec/rspec-expectations/v/2-14/docs/
        # custom-matchers/define-matcher#matching-against-a-regular-expression
        expect(actual.output).to match_regex(expected)
      else
        raise ArgumentError, "don't know what to do with a #{expected.class}"
    end
  end

  failure_message_for_should do |actual|
    case expected
      when String
        what = 'be'
        exp = expected
      when Regexp
        what = 'match'
        exp = "/#{expected.source}/"
      else
        raise ArgumentError, "don't know what to do with a #{expected.class}"
    end

    'expected command to exit with 0 but was ' +
      "#{actual.exit_status}. expected output to " +
      "#{what} '#{exp}' but was\n#{actual.output}"
  end
end
