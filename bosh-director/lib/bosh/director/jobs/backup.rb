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
        @db_adapter = options.fetch(:db_adapter) { Bosh::Director::DbBackup.create(Config.db_config) }
      end

      def perform
        Dir.mktmpdir do |tmp_output_dir|
          event_log.begin_stage('Backing up director', 4)
          backup_database("#{tmp_output_dir}/director_db.sql")
          @tar_gzipper.compress(tmp_output_dir, 'director_db.sql', @backup_file)
          "Backup created at #{@backup_file}"
        end
      end

      private
      def backup_database(output)
        track_and_log('Backing up database') do
          @db_adapter.export(output)
        end
      end
    end
  end
end
