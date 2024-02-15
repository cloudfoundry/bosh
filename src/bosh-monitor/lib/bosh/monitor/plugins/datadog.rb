require 'dogapi'

module Bosh::Monitor
  module Plugins
    class DataDog < Base
      NORMAL_PRIORITY = %i[alert critical error].freeze

      def validate_options
        !!(options.is_a?(Hash) && options['api_key'] && options['application_key'])
      end

      def run
        @api_key = options['api_key']
        @application_key = options['application_key']
        @pagerduty_service_name = options['pagerduty_service_name']

        logger.info('DataDog plugin is running...')
      end

      def dog_client
        return @dog_client if @dog_client

        client = Dogapi::Client.new(@api_key, @application_key)
        @dog_client = @pagerduty_service_name ? PagingDatadogClient.new(@pagerduty_service_name, client) : client
      end

      def custom_tags
        options['custom_tags'] || {}
      end

      def process(event)
        case event
        when Bosh::Monitor::Events::Heartbeat
          EventMachine.defer { process_heartbeat(event) } if event.instance_id
        when Bosh::Monitor::Events::Alert
          EventMachine.defer { process_alert(event) }
        end
      end

      private

      def process_heartbeat(heartbeat)
        tags = %W[
          job:#{heartbeat.job}
          index:#{heartbeat.index}
          id:#{heartbeat.instance_id}
          deployment:#{heartbeat.deployment}
          agent:#{heartbeat.agent_id}
        ]

        heartbeat.teams.each { |team| tags << "team:#{team}" }
        custom_tags.each { |key, value| tags << "#{key}:#{value}" }

        dog_client.batch_metrics do
          heartbeat.metrics.each do |metric|
            point = [Time.at(metric.timestamp), metric.value]
            dog_client.emit_points("bosh.healthmonitor.#{metric.name}", [point], tags: tags)
          rescue Timeout::Error
            logger.warn('Could not emit points to Datadog, request timed out.')
          rescue StandardError => e
            logger.info("Could not emit points to Datadog: #{e.inspect}")
          end
        end
      end

      def process_alert(alert)
        data = alert.to_hash
        # DataDog only supports "low" and "normal" priority
        begin
          dog_client.emit_event(
            Dogapi::Event.new(data[:summary],
                              msg_title: data[:title],
                              date_happened: data[:created_at],
                              tags: tags_for(data),
                              priority: priority_for(alert),
                              alert_type: severity_for(alert)),
          )
        rescue Timeout::Error => e
          logger.warn('Could not emit event to Datadog, request timed out.')
        rescue StandardError => e
          logger.warn("Could not emit event to Datadog: #{e.inspect}")
        end
      end

      def priority_for(alert)
        NORMAL_PRIORITY.include?(alert.severity) ? 'normal' : 'low'
      end

      def severity_for(alert)
        NORMAL_PRIORITY.include?(alert.severity) ? 'error' : 'warning'
      end

      def tags_for(data)
        [].tap do |tags|
          tags << "source:#{data[:source]}"
          tags << "deployment:#{data[:deployment]}"
          custom_tags.each { |key, value| tags << "#{key}:#{value}" }
        end
      end
    end
  end
end
