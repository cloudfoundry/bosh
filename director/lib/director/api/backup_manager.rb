module Bosh::Director
  module Api
    class BackupManager
      include TaskHelper

      attr_accessor :destination_path

      def initialize
        @destination_path = "/var/vcap/store/director"
      end

      def create_backup(user)
        task = create_task(user, :bosh_backup, "bosh backup")
        Resque.enqueue(Bosh::Director::Jobs::Backup, task.id, destination_path)
        task
      end
    end
  end
end
