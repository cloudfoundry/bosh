$:.unshift(File.expand_path("../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)
require "rubygems"
require "bundler"
Bundler.setup(:default, :test)
require "rspec"

ENV["RACK_ENV"] = "test"

require "agent"

require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"

tmpdir = Dir.mktmpdir
ENV["TMPDIR"] = tmpdir
FileUtils.mkdir_p(tmpdir)
at_exit { FileUtils.rm_rf(tmpdir) }

RSpec.configure do |rspec_config|
  rspec_config.before(:each) do
    clear_configuration
    use_dummy_logger
    setup_directories
    disable_monit
  end
end

def use_dummy_logger
  Bosh::Agent::Config.logger = Logger.new(StringIO.new)
end

def setup_directories
  tmpdir = Dir.mktmpdir
  base_dir = File.join(tmpdir, "bosh")
  sys_root = File.join(tmpdir, "system_root")

  FileUtils.mkdir_p(base_dir)
  FileUtils.mkdir_p(sys_root)

  Bosh::Agent::Config.system_root = sys_root
  Bosh::Agent::Config.base_dir = base_dir
end

def clear_configuration
  Bosh::Agent::Config.clear
end

def disable_monit
  Bosh::Agent::Monit.enabled = false
end

def base_dir
  Bosh::Agent::Config.base_dir
end

def read_asset(filename)
  File.open(File.join(File.dirname(__FILE__), 'assets', filename)).read
end

def dummy_package_data
  read_asset('dummy.package')
end

def failing_package_data
  read_asset('failing.package')
end

def dummy_job_data
  read_asset('job.tgz')
end

def get_free_port
  socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
  socket.bind(Addrinfo.tcp("127.0.0.1", 0))
  port = socket.local_address.ip_port
  socket.close
  # race condition, but good enough for now
  port
end
