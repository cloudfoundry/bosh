module Bosh::Monitor
  module Plugins
    class Logger < Base
      def run
        logger.info("Logging delivery agent is running...")
      end

      def validate_options
        options.keys.empty? || options['format'] == 'json'
      end

      def process(event)
        if options['format'] == 'json'
          logger.info(event.to_json)
        else
          logger.info("[#{event.kind.to_s.upcase}] #{event}")
        end
      end
    end
  end
end
