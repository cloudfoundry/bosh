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
          'source' => 'director',
          'title' => 'director - begin update deployment',
          'summary' => "Begin update deployment for '#{@name}' against Director '#{Bosh::Director::Config.uuid}'",
          'created_at' => Time.now.to_i,
          'deployment' => "#{@name}"
        }

        @logger.info('sending update deployment start event')
        @nats_rpc.send_message('hm.director.alert', payload)
      end

      def send_end_event
        payload = {
          'id' => SecureRandom.uuid,
          'severity' => Severity::WARNING,
          'source' => 'director',
          'title' => 'director - finish update deployment',
          'summary' => "Finish update deployment for '#{@name}' against Director '#{Bosh::Director::Config.uuid}'",
          'created_at' => Time.now.to_i,
          'deployment' => "#{@name}"
        }

        @logger.info('sending update deployment end event')
        @nats_rpc.send_message('hm.director.alert', payload)
      end

      def send_begin_instance_event(instance_name, action)
        payload = {
          'id' => SecureRandom.uuid,
          'severity' => Severity::WARNING,
          'source' => 'director',
          'title' => "director - begin '#{action}' instance '#{instance_name}'",
          'summary' => "Finish action '#{action}' for instance '#{instance_name}' \
                       against Director '#{Bosh::Director::Config.uuid}'",
          'created_at' => Time.now.to_i,
          'deployment' => @name.to_s,
        }
        @logger.info("sending instance '#{action}' begin event for instance #{instance_name}")
        @nats_rpc.send_message('hm.director.alert', payload)
      end

      def send_end_instance_event(instance_name, action)
        payload = {
          'id' => SecureRandom.uuid,
          'severity' => Severity::WARNING,
          'source' => 'director',
          'title' => "director - finish '#{action}' instance '#{instance_name}'",
          'summary' => "Finish action '#{action}' for instance '#{instance_name}' \
                       against Director '#{Bosh::Director::Config.uuid}'",
          'created_at' => Time.now.to_i,
          'deployment' => @name.to_s,
        }
        @logger.info("sending instance '#{action}' end event for instance #{instance_name}")
        @nats_rpc.send_message('hm.director.alert', payload)
      end

      def send_error_event(exception)
        payload = {
          'id' => SecureRandom.uuid,
          'severity' => Severity::ERROR,
          'source' => 'director',
          'title' => 'director - error during update deployment',
          'summary' => "Error during update deployment for '#{@name}' against Director '#{Bosh::Director::Config.uuid}': #{exception.inspect}",
          'created_at' => Time.now.to_i,
          'deployment' => "#{@name}"
        }

        @logger.info('sending update deployment error event')
        @nats_rpc.send_message('hm.director.alert', payload)
      end
    end
  end
end
