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
        create_event(alert)
        create_metric(alert)
      end

      def create_event(alert)
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

      def create_metric(alert)
        title, source, timestamp = alert.to_hash.values_at(:title,
                                                           :source,
                                                           :created_at)

        # Hmmm. DataDog was not designed for this.
        # We need to ramp a value up quickly, wait long enough for it to become
        # an alert, then make sure the average over the last 5 minutes goes
        # back to 0.
        ramp_up = [[Time.at(timestamp), 10], [Time.at(timestamp)+60, 10]]
        tear_down = (4..9).map { |minutes| [Time.at(timestamp) + minutes*60, 0]}
        data_points = ramp_up + tear_down

        alert_id = sanitize_for_id(title)
        dog_client.emit_points("bosh.healthmonitor.alerts.#{alert_id}",
                               data_points, tags: tags(source))
      end

      def tags(source)
        %W(source:#{source})
      end

      def normal_priority?(severity)
        NORMAL_PRIORITY.include?(severity)
      end

      def sanitize_for_id(title)
        title.downcase
          .tr("!@#%^&*()+|}{?></.,';\\[]'", "")
          .tr(" -", "_")
          .squeeze("_")
      end
    end
  end
end
