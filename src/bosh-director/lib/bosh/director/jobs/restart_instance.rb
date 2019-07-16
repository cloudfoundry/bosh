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
          instance_model = Models::Instance.find(id: @instance_id)
          raise InstanceNotFound if instance_model.nil?

          Jobs::StopInstance.new(@deployment_name, @instance_id, @options).perform_without_lock
          Jobs::StartInstance.new(@deployment_name, @instance_id, @options).perform_without_lock
        end
      end
    end
  end
end
