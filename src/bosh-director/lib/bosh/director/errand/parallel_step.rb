module Bosh::Director
  class Errand::ParallelStep
    attr_reader :steps

    def initialize(max_in_flight, steps)
      @max_in_flight = max_in_flight
      @steps = steps
    end

    def prepare
      Bosh::ThreadPool.new(max_threads: @max_in_flight, logger: Config.logger).wrap do |pool|
        @steps.each do |step|
          pool.process { step.prepare }
        end
      end
    end

    def run(&checkpoint_block)
      results = []
      mutex = Mutex.new

      Bosh::ThreadPool.new(max_threads: @max_in_flight, logger: Config.logger).wrap do |pool|
        @steps.each do |step|
          pool.process do
            result = step.run(&checkpoint_block)

            mutex.synchronize do
              results << result
            end
          end
        end
      end
      results
    end

    def ignore_cancellation?
      @steps.any?(&:ignore_cancellation?)
    end
  end
end

