module Bosh::Director
  module Jobs
    class ScheduledEventsCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_events_cleanup
      end

      def self.has_work(params = {})
        max_events = params.first['max_events']
        Models::Event.count > max_events
      end

      def self.schedule_message
        "clean up events"
      end

      def initialize(params = {})
        logger.debug("ScheduledEventsCleanup initialized with params: #{params.inspect}")
        @max_events = params['max_events']
      end

      def perform
        logger.info("Started cleanup of events")
        event_manager.remove_old_events(@max_events)
        "Old events were deleted"
      end
    end
  end
end
