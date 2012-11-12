require "rspec"
require "logger"

require "cloud"
require "cloud/warden"

def cloud_options
  {
    "warden" => warden_options,
  }
end

def warden_options
  {
    "unix_domain_socket" => "/tmp/warden.sock",
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
