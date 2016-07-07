require 'riemann/client'

module Bosh::Monitor
  module Plugins
    class Riemann < Base
      def run
        unless EM.reactor_running?
          logger.error("Riemann plugin can only be started when event loop is running")
          return false
        end

        logger.info("Riemann delivery agent is running...")
        return true
      end

      def validate_options
       !!(options.kind_of?(Hash) && options["host"] && options["port"])
      end

      def client
        @client ||= ::Riemann::Client.new host: options["host"], port: options["port"]
        return @client
      end

      def state(event)
        case event.to_hash[:severity]
          when 1
            "critical"
          when nil
            "ok"
          else "warn"
        end
      end

      def process(event)
        client << event.to_hash.merge({
          service: "bosh.hm",
          state: state(event),
        })
      rescue => e
        logger.error("Error sending riemann event: #{e}")
      end
    end
  end
end
