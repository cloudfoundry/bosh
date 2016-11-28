module Bosh::Director
  module Jobs
    class ScheduledBackup < BaseJob
      @queue = :normal

      attr_reader :backup_job

      def self.job_type
        :scheduled_backup
      end

      def initialize(options={})
        @backup_job = options.fetch(:backup_job) { Backup.new(backup_file) }
        @backup_destination = options.fetch(:backup_destination) { App.instance.blobstores.backup_destination }
      end

      def perform
        @backup_job.perform

        blobstore_path = "backup-#{Time.now.utc.iso8601}.tgz"

        File.open(@backup_job.backup_file) do |f|
          @backup_destination.create(f, blobstore_path)
        end

        "Stored '#{blobstore_path}' in backup blobstore"
      ensure
        FileUtils.rm_f(@backup_job.backup_file)
      end

      private

      def backup_file
        File.join(Dir.tmpdir, "backup-#{task_id}.tgz")
      end
    end
  end
end
