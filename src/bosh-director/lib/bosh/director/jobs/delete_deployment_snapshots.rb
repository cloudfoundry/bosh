module Bosh::Director
  module Jobs
    class DeleteDeploymentSnapshots < BaseJob
      @queue = :normal

      attr_reader :deployment

      def self.job_type
        :delete_deployment_snapshots
      end

      def initialize(deployment_name)
        @deployment = deployment_manager.find_by_name(deployment_name)
      end

      def deployment_manager
        @deployment_manager ||= Bosh::Director::Api::DeploymentManager.new
      end

      def perform
        logger.info("deleting snapshots of deployment: #{deployment.name}")
        deployment.job_instances.each do |instance|
          snapshots = instance.persistent_disks.map { |disk| disk.snapshots }.flatten
          if snapshots.any?
            logger.info("deleting snapshots of: #{instance.job}/#{instance.index} (#{instance.active_vm.cid})")
            Bosh::Director::Api::SnapshotManager.delete_snapshots(snapshots)
          end
        end

        "snapshots of deployment '#{deployment.name}' deleted"
      end
    end
  end
end
