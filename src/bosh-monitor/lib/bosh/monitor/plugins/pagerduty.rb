module Bosh::Monitor
  module Plugins
    class Pagerduty < Base
      include Bosh::Monitor::Plugins::HttpRequestHelper

      API_URI = 'https://events.pagerduty.com/generic/2010-04-15/create_event.json'.freeze

      def run
        unless ::Async::Task.current?
          logger.error('Pagerduty plugin can only be started when event loop is running')
          return false
        end

        logger.info('Pagerduty delivery agent is running...')
      end

      def validate_options
        options.is_a?(Hash) &&
          options['service_key'].is_a?(String)
      end

      def process(event)
        payload = {
          service_key: options['service_key'],
          event_type: 'trigger',
          incident_key: event.id,
          description: event.short_description,
          details: event.to_hash,
        }

        request = {
          body: JSON.dump(payload),
        }

        request[:proxy] = options['http_proxy'] if options['http_proxy']

        # Note this appears to be the only use of `#send_http_post_request_synchronous_with_tls_verify_peer` from git
        # history it appears that the previous asynchronous implementation (EventMachine) was not able to use
        # TLS-proxies, so a synchronous call was made from asynchronously.
        # This should probably be re-implemented to use the asynchronous `HttpRequestHelper#send_http_post_request`
        # method _however_ that method should be updated to use `OpenSSL::SSL::VERIFY_PEER`.
        Async do
          send_http_post_request_synchronous_with_tls_verify_peer(API_URI, request)
        rescue StandardError => e
          logger.error("Error sending pagerduty event: #{e}")
        end
      end
    end
  end
end
