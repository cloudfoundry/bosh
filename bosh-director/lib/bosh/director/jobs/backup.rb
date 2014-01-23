require 'bosh/director/core/tar_gzipper'

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
        @tar_gzipper = options.fetch(:tar_gzipper) { Core::TarGzipper.new }
        @blobstore_client = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @db_adapter = options.fetch(:db_adapter) { Bosh::Director::DbBackup.create(Config.db_config) }
        @base_dir = options.fetch(:base_dir) { Config.base_dir }
        @log_dir = options.fetch(:log_dir) { Config.log_dir }
      end

      def perform
        Dir.mktmpdir do |tmp_output_dir|
          event_log.begin_stage('Backing up director', 4)

          files = []

          if @log_dir
            backup_logs("#{tmp_output_dir}/logs.tgz")
            files << 'logs.tgz'
          end

          backup_task_logs("#{tmp_output_dir}/task_logs.tgz")
          files << 'task_logs.tgz'

          backup_database("#{tmp_output_dir}/director_db.sql")
          files << 'director_db.sql'

          backup_blobstore("#{tmp_output_dir}/blobs.tgz")
          files << 'blobs.tgz'

          @tar_gzipper.compress(tmp_output_dir, files, @backup_file)

          "Backup created at #{@backup_file}"
        end
      end

      private
      def backup_logs(output)
        track_and_log('Backing up logs') do
          @tar_gzipper.compress(File.dirname(@log_dir), [File.basename(@log_dir)], output, copy_first: true)
        end
      end

      def backup_task_logs(output)
        track_and_log('Backing up task logs') do
          @tar_gzipper.compress(@base_dir, %w(tasks), output, copy_first: true)
        end
      end

      def backup_database(output)
        track_and_log('Backing up database') do
          @db_adapter.export(output)
        end
      end

      def backup_blobstore(output)
        Dir.mktmpdir do |tmp_dir|
          Dir.mkdir(File.join(tmp_dir, 'blobs'))

          track_and_log('Backing up blobstore') do
            [Models::Package.all, Models::CompiledPackage.all, Models::Template.all].each do |packages|
              packages.each do |package|
                File.open(File.join(tmp_dir, 'blobs', package.blobstore_id), 'w') do |file|
                  logger.debug("Writing file #{file.path}")
                  @blobstore_client.get(package.blobstore_id, file)
                end
              end
            end

            @tar_gzipper.compress(tmp_dir, 'blobs', output)
          end
        end
      end
    end
  end
end
