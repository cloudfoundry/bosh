module Bosh::Director
  module Jobs
    class RestartInstance < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :restart_instance
      end

      def initialize(deployment_name, instance_id, options = {})
        @deployment_name = deployment_name
        @instance_id = instance_id
        @options = options
        @logger = Config.logger
      end

      def perform
        with_deployment_lock(@deployment_name) do
          restart
        end
      end

      def restart
        instance_model = Models::Instance.find(id: @instance_id)
        raise InstanceNotFound if instance_model.nil?

        event_log = Config.event_log

        event_log_stage = event_log.begin_stage("Restarting instance #{instance_model.job}")
        event_log_stage.advance_and_track(instance_model.to_s) do
          Jobs::StopInstance.new(@deployment_name, @instance_id, @options).perform_without_lock
          Jobs::StartInstance.new(@deployment_name, @instance_id, @options).perform_without_lock
        end
      end
    end
  end
end
