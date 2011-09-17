module Bosh::Director
  module Jobs
    class DummyJob < BaseJob

      @queue = :normal

      def initialize(*args)
        super
      end

      def perform
        @logger.info("Performing dummy job")

=begin

        @event_log.begin_stage("Delete deployment", 2, ["dname"])


        instances = [1, 2, 3, 4, 5]
        count = instances.size
        #@event_log.begin_stage("Delete instances", count)

        @event_log.track_and_log("Deleting instances") do |ticker|
          instances.each do |instance|
            ticker.advance(100.0 / count, instance.to_s + "/" + instance.to_s + ("AAAA" * instance))
            sleep(2)
          end
        end
=end


        vms = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      @event_log.begin_stage("Delete idle VMs", 2)

        @event_log.track_and_log("VMs") do |ticker|
          vms.each do |vm|
            ticker.advance(100.0 / vms.size, "aaaaaaaaaaaaaaaaaaaaaaaaaaVM:" + vm.to_s)
            sleep(1)
          end
        end
        sleep(3)

        @event_log.track_and_log("VMs") do |ticker|
                  vms.each do |vm|
                    ticker.advance(100.0 / vms.size, "aaaaaaaaaaaaaaaaaaaaaaaVM:" + vm.to_s)
                    sleep(1)
                  end
                end

        sleep(3)
=begin
        return

        @event_log.begin_stage("Begin Stage 0", 3, ["stage 0000"])
        @event_log.track("Stage 0 1") do  |ticker|
          sleep(3)
          ticker.advance(20)
          sleep(3)
         #end
        #@event_log.track_and_log("Stage 0 2") do |ticker|
          sleep(3)
          ticker.advance(20)
          sleep(3)
        #end
        #@event_log.track_and_log("Stage 0 3") do |ticker|
          sleep(3)
          ticker.advance(20)
          sleep(10)
        end

        @event_log.begin_stage("Begin Stage 1", 10, [])

        ThreadPool.new(:max_threads => 5).wrap do |pool|
          i = 0
          while i < 10 do
            pool.process do
              @event_log.track("Thread " + i.to_s) do
                @logger.info("la")
                sleep(3)
              end
            end
            i += 1
          end
        end

        return
=end
        @event_log.begin_stage("Begin Stage 1", 10, ["stage 0000"])

        i = 0
        while i < 10 do
          @event_log.track("Stage 1/" + i.to_s) do
            @logger.info("Step " + i.to_s)

            sleep(2)
            i += 1
          end
        end

return

        @event_log.begin_stage("Begin Stage 2", 10, ["stage 2"])

        i = 0
        while i < 10 do
          @event_log.track_and_log("Stage 2 task "  +i.to_s ) do
            @logger.info("Step " + i.to_s)
#             sleep(3)
            i += 1
          end
        end

        @logger.info("Done with the dummy job")

      end

    end
  end
end
