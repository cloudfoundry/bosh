require 'securerandom'

module Bosh::Director
  module DeploymentPlan
    class Notifier
      module Severity
        ERROR   = 3
        WARNING = 4
      end

      def initialize(name, nats_rpc, logger)
        @name = name
        @logger = logger
        @nats_rpc = nats_rpc
      end

      def send_start_event
        payload = {
          'id' => SecureRandom.uuid,
          'severity' => Severity::WARNING,
          'title' => 'director - begin update deployment',
          'summary' => "Begin update deployment for '#{@name}' against Director '#{Bosh::Director::Config.uuid}'",
          'created_at' => Time.now.to_i
        }

        @logger.info('sending update deployment start event')
        @nats_rpc.send_message('hm.director.alert', payload)
      end

      def send_end_event
        payload = {
          'id' => SecureRandom.uuid,
          'severity' => Severity::WARNING,
          'title' => 'director - finish update deployment',
          'summary' => "Finish update deployment for '#{@name}' against Director '#{Bosh::Director::Config.uuid}'",
          'created_at' => Time.now.to_i
        }

        @logger.info('sending update deployment end event')
        @nats_rpc.send_message('hm.director.alert', payload)
      end

      def send_error_event(exception)
        payload = {
          'id' => SecureRandom.uuid,
          'severity' => Severity::ERROR,
          'title' => 'director - error during update deployment',
          'summary' => "Error during update deployment for '#{@name}' against Director '#{Bosh::Director::Config.uuid}': #{exception.inspect}",
          'created_at' => Time.now.to_i
        }

        @logger.info('sending update deployment error event')
        @nats_rpc.send_message('hm.director.alert', payload)
      end
    end
  end
end
