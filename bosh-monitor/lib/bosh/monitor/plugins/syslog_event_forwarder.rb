require 'syslog/logger'

module Bosh::Monitor
  module Plugins
    class SyslogEventForwarder < Base

      attr_reader :sys_logger

      def run
        @sys_logger = Syslog::Logger.new('bosh.hm') # keep programname in sync with syslog_event_forwarder.conf.erb
        logger.info("Syslog forwarder is running with programname '#{Syslog::ident}'...")
      end

      def process(event)
        if event.kind_of?(Bosh::Monitor::Events::Alert)
          @sys_logger.info("[#{event.kind.to_s.upcase}] #{event.to_json}")
        end
      end
    end
  end
end