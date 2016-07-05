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

      def process(event)
        case event
        when Bosh::Monitor::Events::Heartbeat
          if event.node_id
            process_heartbeat(event)
          end
        when Bosh::Monitor::Events::Alert
          process_alert(event)
        end
      end

      def process_heartbeat(event)
        payload = event.to_hash.merge({service: "bosh.hm"})
        payload.delete :vitals
        event.metrics.each do |metric|
          begin
            client << payload.merge({
              name: metric.name,
              metric: metric.value,
            })
          rescue => e
            logger.error("Error sending riemann event: #{e}")
          end
        end
      end

      def process_alert(event)
        client << event.to_hash.merge({
          service: "bosh.hm",
          state: event.severity.to_s,
        })
      rescue => e
        logger.error("Error sending riemann event: #{e}")
      end
    end
  end
end
