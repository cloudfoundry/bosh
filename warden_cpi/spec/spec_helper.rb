ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "logger"

require "cloud/warden"

class WardenConfig
  attr_accessor :logger
end

warden_config = WardenConfig.new
warden_config.logger = Logger.new(StringIO.new)
warden_config.logger.level = Logger::DEBUG

Bosh::Clouds::Config.configure(warden_config)
