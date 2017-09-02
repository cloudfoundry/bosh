module Bosh::Director
  class Errand::ParallelStep
    attr_reader :steps

    def initialize(max_in_flight, errand_name, deployment_model, steps)
      @max_in_flight = max_in_flight
      @steps = steps
      @deployment_model = deployment_model
      @errand_name = errand_name
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
      errand_run = Models::ErrandRun.find_or_create(deployment: @deployment_model, errand_name: @errand_name)
      errand_run.update(successful_state_hash: '')

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

      unless results.any? {|r| !r.successful?}
        errand_run.update(successful_state_hash: state_hash)
      end

      results
    end

    def has_not_changed_since_last_success?
      last_run = Models::ErrandRun.first(deployment: @deployment_model, errand_name: @errand_name)
      !last_run.nil? && last_run.successful_state_hash == state_hash
    end

    def config_hash
      hashes = []
      @steps.each do |step|
        hashes << step.config_hash
      end

      hashes.shasum
    end

    def ignore_cancellation?
      @steps.any?(&:ignore_cancellation?)
    end

    def state_hash
      ::Digest::SHA1.hexdigest(@steps.map(&:state_hash).sort.join)
    end
  end
end

