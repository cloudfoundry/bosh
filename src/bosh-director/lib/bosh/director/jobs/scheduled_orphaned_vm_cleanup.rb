module Bosh::Director
  module Jobs
    class ScheduledOrphanedVMCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_orphaned_vm_cleanup
      end

      def self.has_work(_)
        Models::OrphanedVm.any?
      end

      def initialize
        logger.debug('ScheduledOrphanedVMCleanup initialized')
        @orphaned_vm_deleter = OrphanedVMDeleter.new(logger)
      end

      def perform(lock_timeout = 5)
        @orphaned_vm_deleter.delete_all(lock_timeout)
      end
    end
  end
end