module Bosh::Director
  module Api
    class BackupManager
      attr_accessor :destination_path

      def initialize
        @destination_path = '/var/vcap/store/director/backup.tgz'
      end

      def create_backup(user)
        JobQueue.new.enqueue(user, Jobs::Backup, 'bosh backup', [destination_path])
      end
    end
  end
end
