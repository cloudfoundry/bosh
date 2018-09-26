module Bosh::Director
  module Jobs
    class DeleteOrphanNetworks < BaseJob
      include LockHelper
      @queue = :normal

      def self.job_type
        :delete_orphan_networks
      end

      def self.enqueue(username, orphaned_network_names, job_queue)
        orphaned_network_names.each do |network_name|
          network = Bosh::Director::Models::Network.where(name: network_name).first

          raise NetworkNotFoundError, "Deleting non-existing network #{network_name}" if network.nil?
          unless network.orphaned
            raise NetworkDeletingUnorphanedError, "Deleting unorphaned network is not supported: #{network_name}"
          end
        end

        job_queue.enqueue(username, Jobs::DeleteOrphanNetworks, 'delete orphan networks', [orphaned_network_names])
      end

      def initialize(orphaned_network_names)
        @orphaned_network_names = orphaned_network_names
        @orphan_network_manager = OrphanNetworkManager.new(Config.logger)
      end

      def perform
        event_log_stage = Config.event_log.begin_stage('Deleting orphaned networks', @orphaned_network_names.count)
        ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
          @orphaned_network_names.each do |orphan_network_name|
            pool.process do
              event_log_stage.advance_and_track("Deleting orphaned network #{orphan_network_name}") do
                with_network_lock(orphan_network_name) do
                  @orphan_network_manager.delete_network(orphan_network_name)
                end
              end
            end
          end
        end
        "orphaned network(s) #{@orphaned_network_names.join(', ')} deleted"
      end
    end
  end
end
