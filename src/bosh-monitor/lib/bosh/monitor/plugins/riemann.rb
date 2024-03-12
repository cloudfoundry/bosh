require 'riemann/client'

module Bosh::Monitor
  module Plugins
    class Riemann < Base
      def run
        unless ::Async::Task.current?
          logger.error('Riemann plugin can only be started when event loop is running')
          return false
        end

        logger.info('Riemann delivery agent is running...')
        true
      end

      def validate_options
        !!(options.is_a?(Hash) && options['host'] && options['port'])
      end

      def client
        @client ||= ::Riemann::Client.new host: options['host'], port: options['port']
      end

      def process(event)
        case event
        when Bosh::Monitor::Events::Heartbeat
          process_heartbeat(event) if event.instance_id
        when Bosh::Monitor::Events::Alert
          process_alert(event)
        end
      end

      def process_heartbeat(event)
        payload = event.to_hash.merge(service: 'bosh.hm')
        payload.delete :vitals
        event.metrics.each do |metric|
          client << payload.merge(
            name: metric.name,
            metric: metric.value,
          )
        rescue StandardError => e
          logger.error("Error sending riemann event: #{e}")
        end
      end

      def process_alert(event)
        client << event.to_hash.merge(
          service: 'bosh.hm',
          state: event.severity.to_s,
        )
      rescue StandardError => e
        logger.error("Error sending riemann event: #{e}")
      end
    end
  end
end
