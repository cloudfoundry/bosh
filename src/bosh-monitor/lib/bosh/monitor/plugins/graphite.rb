module Bosh::Monitor
  module Plugins
    class Graphite < Base
      def validate_options
        host_port = !!(options.is_a?(Hash) && options['host'] && options['port'])
        if options.key?('max_retries')
          return false unless options['max_retries'].is_a?(Numeric) && options['max_retries'] >= -1
        end
        host_port
      end

      def run
        unless ::Async::Task.current?
          logger.error('Graphite delivery agent can only be started when event loop is running')
          return false
        end

        host = options['host']
        port = options['port']
        retries = options['max_retries'] || Bosh::Monitor::TcpConnection::DEFAULT_RETRIES

        @connection = Bosh::Monitor::GraphiteConnection.new(host, port, retries)
        @connection.connect
      end

      def process(event)
        return unless (event.is_a? Bosh::Monitor::Events::Heartbeat) && event.instance_id

        metrics = event.metrics

        raise PluginError, "Invalid event metrics: Enumerable expected, #{metrics.class} given" unless metrics.is_a?(Enumerable)

        semaphore = Async::Semaphore.new(20)
        metrics.each do |metric|
          semaphore.async do
            metric_name = get_metric_name(event, metric)
            metric_timestamp = get_metric_timestamp(metric.timestamp)
            metric_value = metric.value
            @connection.send_metric(metric_name, metric_value, metric_timestamp)
          end
        end
      end

      private

      def get_metric_name(heartbeat, metric)
        [get_metric_prefix(heartbeat), metric.name.to_s.gsub('.', '_')].join '.'
      end

      def get_metric_prefix(heartbeat)
        deployment = heartbeat.deployment
        job = heartbeat.job
        id = heartbeat.instance_id
        agent_id = heartbeat.agent_id
        if options['prefix']
          [options['prefix'], deployment, job, id, agent_id].join '.'
        else
          [deployment, job, id, agent_id].join '.'
        end
      end

      def get_metric_timestamp(timestamp)
        return timestamp if timestamp && epoch?(timestamp)

        Time.now.to_i
      end

      def epoch?(timestamp)
        /^1[0-9]{9}$/.match(timestamp.to_s)
      end
    end
  end
end
