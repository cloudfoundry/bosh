require 'json'

module Bosh::Monitor
  module Plugins
    class Otlp < Base
      include Bosh::Monitor::Plugins::HttpRequestHelper

      OTLP_METRICS_PATH = '/v1/metrics'.freeze

      def validate_options
        options.is_a?(Hash) && options['endpoint'].is_a?(String)
      end

      def run
        unless ::Async::Task.current?
          logger.error('OTLP plugin can only be started when event loop is running')
          return false
        end

        logger.info('OTLP delivery agent is running...')
      end

      def process(event)
        return unless event.is_a?(Bosh::Monitor::Events::Heartbeat) && event.instance_id

        send_http_post_request(
          uri: "#{options['endpoint']}#{OTLP_METRICS_PATH}",
          request: {
            head: {
              'Content-Type' => 'application/json',
            },
            body: build_otlp_payload(event),
          },
          ca_cert_path: options['ca_cert'],
        )
      end

      private

      def build_otlp_payload(event)
        # Timestamp in nanoseconds as OTLP requires
        timestamp_ns = (event.timestamp || Time.now.to_i) * 1_000_000_000

        data_points = event.metrics.map do |metric|
          {
            'asDouble' => metric.value.to_f,
            'timeUnixNano' => timestamp_ns.to_s,
            'attributes' => [],
          }
        end

        scope_metrics = event.metrics.each_with_index.map do |metric, i|
          {
            'name' => metric.name,
            'gauge' => {
              'dataPoints' => [data_points[i]],
            },
          }
        end

        payload = {
          'resourceMetrics' => [
            {
              'resource' => {
                'attributes' => [
                  { 'key' => 'bosh.deployment', 'value' => { 'stringValue' => event.deployment.to_s } },
                  { 'key' => 'bosh.job',        'value' => { 'stringValue' => event.job.to_s } },
                  { 'key' => 'bosh.id',         'value' => { 'stringValue' => event.instance_id.to_s } },
                  { 'key' => 'bosh.agent_id',   'value' => { 'stringValue' => event.agent_id.to_s } },
                ],
              },
              'scopeMetrics' => [
                {
                  'scope' => { 'name' => 'bosh-health-monitor' },
                  'metrics' => scope_metrics,
                },
              ],
            },
          ],
        }

        JSON.dump(payload)
      end
    end
  end
end
