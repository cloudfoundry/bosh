module Bosh::Director::Api
  module SyslogHelper

    begin
      require 'syslog/logger'
    rescue LoadError
      puts "Failed to load Syslog::Logger. Ruby version #{RUBY_VERSION} not supported. Use RUBY_VERSION >= 2.0.0"
    end

    def syslog(level, message)
      if SyslogHelper.syslog_supported
        logger = Syslog::Logger.new('vcap.bosh.director')
        logger.send(level, message)
      end
    end

    def self.syslog_supported
      RUBY_VERSION.to_i > 1
    end
  end
end
