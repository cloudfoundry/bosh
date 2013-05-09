module Bosh::Director
  module Jobs
    class SnapshotDeployment < BaseJob
      @queue = :normal

      attr_reader :deployment

      def initialize(deployment_name, options = {})
        @deployment = deployment_manager.find_by_name(deployment_name)
        @options = options
      end

      def deployment_manager
        @deployment_manager ||= Bosh::Director::Api::DeploymentManager.new
      end

      def perform
        logger.info("taking snapshot of: #{deployment.name}")
        deployment.job_instances.each do |instance|
          logger.info("taking snapshot of: #{instance.job}/#{instance.index} (#{instance.vm.cid})")
          Bosh::Director::Api::SnapshotManager.take_snapshot(instance, @options)
        end

        "snapshots of deployment `#{deployment.name}' created"
      end
    end
  end
end

