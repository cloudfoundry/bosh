# Copyright (c) 2009-2012 VMware, Inc.

require "rspec"

ENV["RACK_ENV"] = "test"

require "bosh_agent"

require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"
require "httpclient"

tmpdir = Dir.mktmpdir
ENV["TMPDIR"] = tmpdir
FileUtils.mkdir_p(tmpdir)
at_exit do
  begin
    if $!
      status = $!.is_a?(::SystemExit) ? $!.status : 1
    else
      status = 0
    end
    FileUtils.rm_rf(tmpdir)
  ensure
    exit status
  end
end

RSpec.configure do |rspec_config|
  rspec_config.before(:each) do
    clear_configuration
    use_dummy_logger
    setup_directories
    disable_monit
  end

  rspec_config.before(:each, dummy_infrastructure: true) { setup_dummy_infrastructure }
end

def use_dummy_logger
  Bosh::Agent::Config.logger = Logger.new(StringIO.new)
end

def setup_directories
  tmpdir = Dir.mktmpdir
  base_dir = File.join(tmpdir, "bosh")
  sys_root = File.join(tmpdir, "system_root")

  FileUtils.mkdir_p(base_dir)
  FileUtils.mkdir_p(File.join(base_dir, "packages"))
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

def asset(filename)
  File.join(File.dirname(__FILE__), 'assets', filename)
end

def read_asset(filename)
  File.open(asset(filename)).read
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

def setup_dummy_infrastructure
  Bosh::Agent::Config.infrastructure_name = 'dummy'
end