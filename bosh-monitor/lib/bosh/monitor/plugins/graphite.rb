module Bosh::Monitor
  module Plugins
    class Graphite < Base
      def validate_options
        !!(options.kind_of?(Hash) && options["host"] && options["port"])
      end

      def run
        unless EM.reactor_running?
          logger.error("Graphite delivery agent can only be started when event loop is running")
          return false
        end

        host = options["host"]
        port = options["port"]
        @connection = EM.connect(host, port, Bhm::GraphiteConnection, host, port)
      end

      def process(event)
        if event.is_a? Bosh::Monitor::Events::Heartbeat

          metrics = event.metrics

          unless metrics.kind_of?(Enumerable)
            raise PluginError, "Invalid event metrics: Enumerable expected, #{metrics.class} given"
          end

          metrics.each do |metric|
            metric_name = get_metric_name(event, metric)
            metric_timestamp = get_metric_timestamp(metric.timestamp)
            metric_value = metric.value
            @connection.send_metric(metric_name, metric_value, metric_timestamp)
          end
        end
      end

      private

      def get_metric_name heartbeat, metric
        [get_metric_prefix(heartbeat), metric.name.to_s.gsub('.', '_')].join '.'
      end

      def get_metric_prefix(heartbeat)
        deployment = heartbeat.deployment
        job = heartbeat.job
        index = heartbeat.index
        agent_id = heartbeat.agent_id
        if options["prefix"]
          [options["prefix"], deployment, job, index, agent_id].join '.'
        else
          [deployment, job, index, agent_id].join '.'
        end
      end

      def get_metric_timestamp(ts)
        if ts && is_epoch?(ts)
          return ts
        end

        Time.now.to_i
      end

      def is_epoch?(ts)
        /^1[0-9]{9}$/.match(ts.to_s)
      end
    end
  end
end
