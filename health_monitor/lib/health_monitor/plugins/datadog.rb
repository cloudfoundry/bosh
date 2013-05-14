require 'dogapi'

module Bosh::HealthMonitor
  module Plugins
    class DataDog < Base

      NORMAL_PRIORITY = [:alert, :critical, :error]

      def validate_options
        options.kind_of?(Hash) &&
            options["api_key"] &&
            options["application_key"]
      end

      def run
        @api_key = options["api_key"]
        @application_key = options["application_key"]
        logger.info("DataDog plugin is running...")
      end

      def dog_client
        @dog_client ||= Dogapi::Client.new(@api_key, @application_key)
      end

      def process(event)
        case event
          when Bosh::HealthMonitor::Events::Heartbeat
            EM.defer { process_heartbeat(event) }
          when Bosh::HealthMonitor::Events::Alert
            EM.defer { process_alert(event) }
          else
            #ignore
        end
      end

      private

      def process_heartbeat(heartbeat)
        tags = %W[
          job:#{heartbeat.job}
          index:#{heartbeat.index}
          deployment:#{heartbeat.deployment}
          agent:#{heartbeat.agent_id}
        ]

        heartbeat.metrics.each do |metric|
          point = [Time.at(metric.timestamp), metric.value]
          dog_client.emit_points("bosh.healthmonitor.#{metric.name}", [point], tags: tags)
        end
      end

      def process_alert(alert)
        msg, title, source, timestamp = alert.to_hash.values_at(:summary,
                                                                :title,
                                                                :source,
                                                                :created_at)


        # DataDog only supports "low" and "normal" priority
        priority = normal_priority?(alert.severity) ? "normal" : "low"
        dog_client.emit_event(
          Dogapi::Event.new(msg,
            msg_title: title,
            date_happened: timestamp,
            tags: ["source:#{source}"],
            priority: priority
          )
        )
      end

      def normal_priority?(severity)
        NORMAL_PRIORITY.include?(severity)
      end
    end
  end
end
