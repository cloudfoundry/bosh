module Bosh::Director
  module Jobs
    class ScheduledDnsTombstoneCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_dns_tombstone_cleanup
      end

      def self.has_work(_)
        Bosh::Director::Models::LocalDnsRecord.where(Sequel.like(:ip, '%-tombstone')).count > 1
      end

      def self.schedule_message
        'clean up local dns tombstone records'
      end

      def initialize
      end

      def perform
        count = Bosh::Director::Models::LocalDnsRecord.prune_tombstones
        "Deleted #{count} dns tombstone records"
      end
    end
  end
end
