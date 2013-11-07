require 'rspec'
require 'logger'
require 'tmpdir'
require 'cloud'
require 'cloud/warden'

def asset(file)
  File.join(File.dirname(__FILE__), 'assets', file)
end

def mock_sh (cmd, su = false, times = 1, success = true)
  zero_exit_status = mock('Process::Status', exit_status: 0)
  result = mock('Result', :success? => success)
  prefix = (su == true)? 'sudo -n ' : ''
  Bosh::Exec.should_receive(:sh).exactly(times).times.with(/#{prefix}#{cmd}/, yield: :on_false).and_yield(result).and_return(zero_exit_status)
end

RSpec.configure do |conf|
  conf.before(:each) { Bosh::Clouds::Config.stub(:logger).and_return(double.as_null_object)  }
end