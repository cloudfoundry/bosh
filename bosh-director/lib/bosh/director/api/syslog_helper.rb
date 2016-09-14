module Bosh::Director::Api
  module SyslogHelper

    begin
      require 'syslog/logger'
    rescue LoadError
      puts "Failed to load Syslog::Logger. Ruby version #{RUBY_VERSION} not supported. Use RUBY_VERSION >= 2.0.0"
    end

    def syslog
      Syslog::Logger.new('vcap.bosh.director')
    end
  end
end
