module Bosh::Director
  module Jobs
    class CleanupArtifacts < BaseJob
      @queue = :normal

      def self.job_type
        :delete_artifacts
      end

      def self.enqueue(username, config, job_queue)
        description = config['remove_all'] ? 'clean up all' : 'clean up'
        job_queue.enqueue(username, Jobs::CleanupArtifacts, description, [config])
      end

      def initialize(config)
        @config = config
      end

      def perform
        CleanupArtifactManager.new(@config['remove_all'], logger).delete
      end
    end
  end
end
