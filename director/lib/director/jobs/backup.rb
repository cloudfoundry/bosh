module Bosh::Director
  module Jobs
    class Backup < BaseJob

      @queue = :normal

      def initialize(dest_dir, options={})
        @dest_dir = dest_dir
        @tar_gzipper = options.fetch(:tar_gzipper, Bosh::Director::TarGziper.new)
      end

      def perform
        event_log.begin_stage("Backing up director", 3)

        files = []

        files << backup_logs
        files << backup_task_logs
        files << backup_database
        # TODO: back_up_blobstore

        backup_file = "#{@dest_dir}/backup.tgz"
        @tar_gzipper.compress(files, backup_file)
        "Backup created at #{backup_file}"
      end

      def backup_logs
        output = "#{@dest_dir}/logs.tgz"

        track_and_log("Backing up logs") do
          @tar_gzipper.compress("/var/vcap/sys/log", output)
        end

        output
      end

      def backup_task_logs
        output = "#{@dest_dir}/task_logs.tgz"

        track_and_log("Backing up task logs") do
          @tar_gzipper.compress("/var/vcap/store/director/tasks", output)
        end

        output
      end

      def backup_database
        output = "#{@dest_dir}/director_db.sql"

        track_and_log("Backing up database") do
          @db_adapter_creator ||= Bosh::Director::DbBackup
          db_adapter = db_adapter_creator.create(Config.db_config)
          db_adapter.export(output)
        end

        output
      end

      attr_accessor :db_adapter_creator

    end
  end
end
