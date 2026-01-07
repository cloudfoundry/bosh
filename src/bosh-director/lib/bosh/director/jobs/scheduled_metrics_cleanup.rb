module Bosh::Director
  module Jobs
    class ScheduledMetricsCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_metrics_cleanup
      end

      def self.has_work(params)
        return false if params.first['retention_days'] <= 0

        metrics_dir = Config.metrics_dir
        return false unless File.directory?(metrics_dir)

        cutoff_time = time_days_ago(params.first['retention_days'])

        # Check if there are any files older than retention period
        Dir.glob(File.join(metrics_dir, 'metric_*.bin')).any? do |file|
          File.mtime(file) < cutoff_time
        end
      end

      def self.time_days_ago(days)
        Time.now - (days * 24 * 60 * 60)
      end

      def self.schedule_message
        'clean up stale metrics files'
      end

      def initialize(params = {}) # rubocop:disable Lint/MissingSuper
        @retention_days = params['retention_days']
        @metrics_dir = Config.metrics_dir
      end

      def perform
        return 'Metrics cleanup disabled (retention_days is 0)' if @retention_days <= 0
        return "Metrics directory does not exist: #{@metrics_dir}" unless File.directory?(@metrics_dir)

        cutoff_time = self.class.time_days_ago(@retention_days)
        logger.info("Started cleanup of metrics files older than #{cutoff_time} from #{@metrics_dir}")

        files_to_delete = stale_files(cutoff_time)
        deleted_count, failed_count = delete_files(files_to_delete)

        output = "Deleted #{deleted_count} metrics file(s) older than #{cutoff_time}."
        output << " Failed to delete #{failed_count} file(s)." if failed_count.positive?
        logger.info(output)
        output
      end

      private

      def stale_files(cutoff_time)
        Dir.glob(File.join(@metrics_dir, 'metric_*.bin')).select do |file|
          File.mtime(file) < cutoff_time
        end
      end

      def delete_files(files)
        deleted_count = 0
        failed_count = 0

        files.each do |file|
          File.delete(file)
          deleted_count += 1
          logger.debug("Deleted metrics file: #{file}")
        rescue StandardError => e
          failed_count += 1
          logger.warn("Failed to delete metrics file #{file}: #{e.message}")
        end

        [deleted_count, failed_count]
      end
    end
  end
end
