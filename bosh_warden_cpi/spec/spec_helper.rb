require 'rspec'
require 'logger'
require 'tmpdir'

module Helper
  def cloud_options
    {
      'agent' => agent_options,
      'warden' => warden_options,
      'stemcell' => stemcell_options,
      'disk' => disk_options,
    }
  end

  def agent_options
    {
      'blobstore' => {
        'plugin' => 'simple',
        'properties' => {},
      },
      'mbus' => 'nats://nats:nats@localhost:4222',
      'ntp' => [],
    }
  end

  def warden_options
    {
      'unix_domain_socket' => '/tmp/warden.sock',
    }
  end

  def stemcell_options
    @stemcell_root ||= File.join(tmpdir, 'stemcell').tap do |e|
      FileUtils.mkdir_p(e)
    end

    {
      'root' => @stemcell_root,
    }
  end

  def disk_options
    @disk_root ||= File.join(tmpdir, 'disk').tap do |e|
      FileUtils.mkdir_p(e)
    end

    {
      'root' => @disk_root,
    }
  end

  def tmpdir
    @tmpdir ||= Dir.mktmpdir
  end
end

require 'cloud'

class WardenConfig
  attr_accessor :logger, :uuid
end

config = WardenConfig.new
config.logger = Logger.new('/dev/null')
config.uuid = '1024'

Bosh::Clouds::Config.configure(config)

require 'cloud/warden'

def asset(file)
  File.join(File.dirname(__FILE__), 'assets', file)
end

def image_file(disk_id)
  "#{disk_id}.img"
end

def mock_sh (cmd, su = false, times = 1, success = true)
  zero_exit_status = mock('Process::Status', exit_status: 0)
  result = mock('Result', :success? => success)
  prefix = (su == true)? 'sudo -n ' : ''
  Bosh::Exec.should_receive(:sh).exactly(times).times.with(/#{prefix}#{cmd}.*/, yield: :on_false).and_yield(result).and_return(zero_exit_status)
end



RSpec.configure do |conf|
  conf.include(Helper)
end