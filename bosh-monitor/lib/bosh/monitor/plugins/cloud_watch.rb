require 'aws-sdk'

module Bosh::Monitor
  module Plugins
    class CloudWatch < Base
      def initialize(options={})
        @options = options
      end

      def aws_cloud_watch
        @aws_cloud_watch ||= AWS::CloudWatch.new(@options)
      end

      def run
      end

      def process(event)
        if (event.is_a? Bosh::Monitor::Events::Heartbeat) && event.node_id
          aws_cloud_watch.put_metric_data(heartbeat_to_cloudwatch_metric(event))
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
            {name: "name", value: "#{heartbeat.job}/#{heartbeat.node_id}"},
            {name: "deployment", value: heartbeat.deployment},
            {name: "agent_id", value: heartbeat.agent_id},
            {name: "id", value: heartbeat.node_id}
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
