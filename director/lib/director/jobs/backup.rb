module Bosh::Director
  module Jobs
    class Backup < BaseJob
      @queue = :normal

      def self.job_type
        :bosh_backup
      end

      attr_reader :backup_file

      def initialize(dest, options={})
        @backup_file = dest
        @tar_gzipper = options.fetch(:tar_gzipper) { TarGzipper.new }
        @blobstore_client = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @db_adapter = options.fetch(:db_adapter) { Bosh::Director::DbBackup.create(Config.db_config) }
      end

      def perform
        Dir.mktmpdir do |tmp_output_dir|
          event_log.begin_stage('Backing up director', 3)

          files = []

          backup_logs("#{tmp_output_dir}/logs.tgz")
          files << 'logs.tgz'

          backup_task_logs("#{tmp_output_dir}/task_logs.tgz")
          files << 'task_logs.tgz'

          backup_database("#{tmp_output_dir}/director_db.sql")
          files << 'director_db.sql'

          begin
            backup_blobstore("#{tmp_output_dir}/blobs.tgz")
            files << 'blobs.tgz'
          rescue Bosh::Blobstore::NotImplemented
            logger.warn('Skipping blobstore backup because blobstore client does not support list operation')
          end

          @tar_gzipper.compress(tmp_output_dir, files, @backup_file)

          "Backup created at #{@backup_file}"
        end
      end

      private
      def backup_logs(output)
        track_and_log('Backing up logs') do
          @tar_gzipper.compress('/', ['var/vcap/sys/log'], output)
        end
      end

      def backup_task_logs(output)
        track_and_log('Backing up task logs') do
          @tar_gzipper.compress('/', ['var/vcap/store/director/tasks'], output)
        end
      end

      def backup_database(output)
        track_and_log('Backing up database') do
          @db_adapter.export(output)
        end
      end

      def backup_blobstore(output)
        Dir.mktmpdir do |blobs_dir|

          track_and_log('Backing up blobstore') do
            files = @blobstore_client.list

            files.each do |file_id|
              File.open("#{blobs_dir}/#{file_id}", 'w') do |file|
                logger.debug("Writing file #{file.path}")
                @blobstore_client.get(file_id, file)
              end
            end

            @tar_gzipper.compress(blobs_dir, files, output)
          end
        end
      end
    end
  end
end
