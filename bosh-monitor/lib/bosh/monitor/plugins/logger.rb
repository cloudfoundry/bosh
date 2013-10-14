module Bosh::Monitor
  module Plugins
    class Logger < Base
      def run
        logger.info("Logging delivery agent is running...")
      end

      def process(event)
        logger.info("[#{event.kind.to_s.upcase}] #{event}")
      end
    end
  end
end
