module Bosh::Director
  module Jobs
    class DummyJob < BaseJob

      @queue = :normal

      def initialize(*args)
        super
      end

      def perform
        @logger.info("Performing dummy job")

        @event_log.begin_stage("Begin Stage 1", 2, ["stage 1"])

        i = 0
        while i < 10 do
          @event_log.track_and_log("Stage 1 task 1") do   | ticker |
            @logger.info("Step " + i.to_s)
            ticker.advance(10, "Step " + i.to_s)
            sleep(3)
          end
        end

        i = 0
        while i < 10 do
          @event_log.track_and_log("Stage 1 task 2") do   | ticker |
            @logger.info("Step " + i.to_s)
            ticker.advance(10, "Step " + i.to_s)
            sleep(3)
          end
        end

        @event_log.begin_stage("Begin Stage 2", 1, ["stage 2"])

        i = 0
        while i < 10 do
          @event_log.track_and_log("Stage 2 task 1") do   | ticker |
            @logger.info("Step " + i.to_s)
            ticker.advance(10, "Step " + i.to_s)
            sleep(3)
          end
        end

        @logger.info("Done with the dummy job")

      end

    end
  end
end
