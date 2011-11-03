module Bosh::HealthMonitor
  module Plugins
    class Tsdb < Base

      def validate_options
        options.kind_of?(Hash) &&
          options["host"] &&
          options["port"] &&
          true
      end

      def run
        unless EM.reactor_running?
          logger.error("TSDB delivery agent can only be started when event loop is running")
          return false
        end

        host = options["host"]
        port = options["port"]
        @tsdb = EM.connect(host, port, Bhm::TsdbConnection, host, port)
      end

      def process(event)
        if @tsdb.nil?
          @logger.error("Cannot deliver event, TSDB connection is not initialized")
          return false
        end

        metrics = event.metrics

        if !metrics.kind_of?(Enumerable)
          raise PluginError, "Invalid event metrics: Enumerable expected, #{metrics.class} given"
        end

        metrics.each do |metric|
          @tsdb.send_metric(metric.name, metric.timestamp, metric.value, metric.tags)
        end

        true
      end
    end
  end
end
