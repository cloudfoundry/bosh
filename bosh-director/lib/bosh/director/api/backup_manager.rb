module Bosh::Director
  module Api
    class BackupManager
      attr_reader :destination_path

      def initialize
        @destination_path = '/var/vcap/store/director/backup.tgz'
      end

      def create_backup(username)
        JobQueue.new.enqueue(username, Jobs::Backup, 'bosh backup', [destination_path])
      end
    end
  end
end
