require 'securerandom'

module Bosh::Director
  module DeploymentPlan
    class Notifier
      module Severity
        ERROR   = 3
        WARNING = 4
      end

      def initialize(planner, logger)
        @planner = planner
        @logger = logger
      end

      def send_start_event
        payload = Yajl::Encoder.encode(
          'id' => SecureRandom.uuid,
          'severity' => Severity::WARNING,
          'title' => 'director - begin update deployment',
          'summary' => "Begin update deployment for #{@planner.canonical_name} against Director #{Bosh::Director::Config.uuid}",
          'created_at' => Time.now.to_i
          )

        @logger.info('sending update deployment start event')
        Bosh::Director::Config.nats.publish('hm.director.alert', payload)
      end

      def send_end_event
        payload = Yajl::Encoder.encode(
          'id' => SecureRandom.uuid,
          'severity' => Severity::WARNING,
          'title' => 'director - finish update deployment',
          'summary' => "Finish update deployment for #{@planner.canonical_name} against Director #{Bosh::Director::Config.uuid}",
          'created_at' => Time.now.to_i
          )

        @logger.info('sending update deployment end event')
        Bosh::Director::Config.nats.publish('hm.director.alert', payload)
      end

      def send_error_event(exception)
        payload = Yajl::Encoder.encode(
          'id' => SecureRandom.uuid,
          'severity' => Severity::ERROR,
          'title' => 'director - error during update deployment',
          'summary' => "Error during update deployment for #{@planner.canonical_name} against Director #{Bosh::Director::Config.uuid}: #{exception.inspect}",
          'created_at' => Time.now.to_i
          )

        @logger.info('sending update deployment error event')
        Bosh::Director::Config.nats.publish('hm.director.alert', payload)
      end
    end
  end
end
