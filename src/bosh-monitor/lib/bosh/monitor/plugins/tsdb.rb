module Bosh::Monitor
  module Plugins
    class Tsdb < Base
      def validate_options
        host_port = !!(options.is_a?(Hash) && options['host'] && options['port'])
        if options.key?('max_retries')
          return false unless options['max_retries'].is_a?(Numeric) && options['max_retries'] >= -1
        end
        host_port
      end

      def run
        unless ::Async::Task.current?
          logger.error('TSDB delivery agent can only be started when event loop is running')
          return false
        end

        host = options['host']
        port = options['port']
        retries = options['max_retries'] || Bhm::TcpConnection::DEFAULT_RETRIES
        @tsdb = Bhm::TsdbConnection.new(host, port, retries)
        @tsdb.connect
      end

      def process(event)
        if @tsdb.nil?
          @logger.error('Cannot deliver event, TSDB connection is not initialized')
          return false
        end

        return false if event.is_a? Bosh::Monitor::Events::Alert

        metrics = event.metrics

        raise PluginError, "Invalid event metrics: Enumerable expected, #{metrics.class} given" unless metrics.is_a?(Enumerable)

        semaphore = Async::Semaphore.new(20)
        metrics.each do |metric|
          semaphore.async do
            tags = metric.tags.merge(deployment: event.deployment)
            tags.delete_if { |_key, value| value.to_s.strip == '' }
            @tsdb.send_metric(metric.name, metric.timestamp, metric.value, tags)
          end
        end

        true
      end
    end
  end
end
