module Bosh::Director
  module Jobs
    class ScheduledOrphanedNetworkCleanup < BaseJob
      include LockHelper
      @queue = :normal

      def self.job_type
        :scheduled_orphaned_network_cleanup
      end

      def self.has_work(params)
        time = time_days_ago(params.first['max_orphaned_age_in_days'])
        Models::Network.where(Sequel.lit('orphaned = ? and orphaned_at < ?', true, time)).any?
      end

      def self.time_days_ago(days)
        Time.now - (days * 24 * 60 * 60)
      end

      def self.schedule_message
        'clean up networks'
      end

      def initialize(params = {})
        logger.debug("ScheduledNetworkCleanup initialized with params: #{params.inspect}")
        @max_orphaned_age_in_days = params['max_orphaned_age_in_days']
        @orphan_network_manager = OrphanNetworkManager.new(logger)
      end

      def perform
        time = self.class.time_days_ago(@max_orphaned_age_in_days)
        logger.info("Started cleanup of orphaned networks older than #{time}")

        old_orphans = Models::Network.where(Sequel.lit('orphaned = ? and orphaned_at < ?', true, time))
        old_orphans_count = old_orphans.count
        stage = Config.event_log.begin_stage('Deleting orphan networks', old_orphans_count)
        failed_orphan_network_count = 0
        old_orphans.each do |old_orphan|
          stage.advance_and_track(old_orphan.name) do
            begin
              with_network_lock(old_orphan.name) do
                @orphan_network_manager.delete_network(old_orphan.name)
              end
            rescue StandardError => e
              failed_orphan_network_count += 1
              logger.warn(e.backtrace.join("\n"))
              logger.info("Failed to delete orphan network #{old_orphan.name}. Failed with #{e.message}")
            end
          end
        end

        output = "Deleted #{old_orphans_count - failed_orphan_network_count} orphaned networks(s) older than #{time}. Failed to delete #{failed_orphan_network_count} network(s)."
        raise Bosh::Clouds::CloudError.new(output) if failed_orphan_network_count.positive?
        output
      end
    end
  end
end
