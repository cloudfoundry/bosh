require "rspec"
require "logger"
require "tmpdir"

require "cloud"
require "cloud/warden"

def cloud_options
  {
    "warden" => warden_options,
    "stemcell" => stemcell_options,
  }
end

def warden_options
  {
    "unix_domain_socket" => "/tmp/warden.sock",
  }
end

def stemcell_options
  {
    "root" => "/var/vcap/stemcell",
  }
end

module Bosh::Clouds
  class Config
    class << self
      attr_accessor :logger
    end
  end
end

Bosh::Clouds::Config.logger = Logger.new("/dev/null")
