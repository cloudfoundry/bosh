module Bosh::HealthMonitor
  module Plugins
    class CloudWatch < Base
      attr_reader :aws_cloudwatch
      def initialize(aws_cloudwatch)
        @aws_cloudwatch=aws_cloudwatch
      end

      def run
      end

      def process(event)
        case event
          when Bosh::HealthMonitor::Events::Heartbeat
            aws_cloudwatch.put_metric_data(heartbeat_to_cloudwatch_metric(event))
          else
            raise "Unsupported Event type"
        end
      end

      private

      def heartbeat_to_cloudwatch_metric(heartbeat)
        {
            namespace: "BOSH/HealthMonitor",
            metric_data: heartbeat.metrics.collect do |metric|
              build_metric(metric, dimensions(heartbeat))
            end
        }
      end

      def dimensions(heartbeat)
        @dimensions ||= [
            {name: "job", value: heartbeat.job},
            {name: "index", value: heartbeat.index},
            {name: "name", value: "#{heartbeat.job}/#{heartbeat.index}"},
            {name: "deployment", value: heartbeat.deployment},
            {name: "agent_id", value: heartbeat.agent_id}
        ]
      end

      def build_metric(metric, dimensions)
        timestamp = Time.at(metric.timestamp).utc.iso8601

        {
            metric_name: metric.name.to_s,
            value: metric.value.to_s,
            timestamp: timestamp,
            dimensions: dimensions
        }
      end
    end
  end
end
