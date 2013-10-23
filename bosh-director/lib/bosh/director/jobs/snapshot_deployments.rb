module Bosh::Director
  module Jobs
    class SnapshotDeployments < BaseJob
      @queue = :normal

      def self.job_type
        :snapshot_deployments
      end

      def initialize(options={})
        @snapshot_manager = options.fetch(:snapshot_manager) { Bosh::Director::Api::SnapshotManager.new }
      end

      def perform
        tasks = Models::Deployment.all.map do |deployment|
          @snapshot_manager.create_deployment_snapshot_task('scheduler', deployment)
        end

        "Enqueued snapshot tasks [#{tasks.map(&:id).join(', ')}]"
      end
    end
  end
end
