module Bosh::Director
  class Starter
    class << self
      def start(
        instance:,
        agent_client:,
        update_config:,
        is_canary: false,
        wait_for_running: true,
        logger: Config.logger
      )
        logger.info("Running pre-start for #{instance}")
        agent_client.run_script('pre-start', {})

        logger.info("Starting instance #{instance}")
        agent_client.start

        return unless update_config && wait_for_running

        min_watch_time = is_canary ? update_config.min_canary_watch_time : update_config.min_update_watch_time
        max_watch_time = is_canary ? update_config.max_canary_watch_time : update_config.max_update_watch_time

        wait_until_running(instance, agent_client, min_watch_time, max_watch_time, logger)

        logger.info("Running post-start for #{instance}")
        agent_client.run_script('post-start', {})
      end

      private

      def wait_until_running(instance, agent_client, min_watch_time, max_watch_time, logger)
        current_state = {}

        watch_schedule(min_watch_time, max_watch_time).each do |watch_time|
          begin
            sleep_time = watch_time.to_f / 1000
            Config.job_cancelled?
            logger.info("Waiting for #{sleep_time} seconds to check #{instance} status")
            sleep(sleep_time)
            logger.info("Checking if #{instance} has been updated after #{sleep_time} seconds")

            current_state = agent_client.get_state

            break if current_state['job_state'] == 'running'
          rescue Bosh::Director::TaskCancelled
            logger.debug('Task was cancelled. Stop waiting for the desired state')
            raise
          end
        end

        raise AgentJobNotRunning if current_state['job_state'] != 'running'
      end

      # Returns an array of wait times distributed
      # on the [min_watch_time..max_watch_time] interval.
      #
      # Tries to respect intervals but doesn't allow an interval to
      # fall below 1 second or go over 15 seconds.
      # All times are in milliseconds.
      # @param [Numeric] min_watch_time minimum time to watch the jobs
      # @param [Numeric] max_watch_time maximum time to watch the jobs
      # @return [Array<Numeric>] watch schedule
      def watch_schedule(min_watch_time, max_watch_time)
        delta = (max_watch_time - min_watch_time).to_f
        watch_intervals = 10
        step = [1000, delta / (watch_intervals - 1), 15000].sort[1]

        [min_watch_time] + ([step] * (delta / step).floor)
      end
    end
  end
end
