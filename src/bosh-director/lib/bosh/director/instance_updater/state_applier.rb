module Bosh::Director
  class InstanceUpdater::StateApplier
    def initialize(instance_plan, agent_client, rendered_job_templates_cleaner, logger, options)
      @instance_plan = instance_plan
      @instance = @instance_plan.instance
      @agent_client = agent_client
      @rendered_job_templates_cleaner = rendered_job_templates_cleaner
      @logger = logger
      @is_canary = options.fetch(:canary, false)
    end

    def apply(update_config, run_post_start = true)
      @instance.apply_vm_state(@instance_plan.spec)
      @instance.update_templates(@instance_plan.templates)
      @rendered_job_templates_cleaner.clean

      if @instance.state == 'started'
        @logger.info("Running pre-start for #{@instance}")
        @agent_client.run_script('pre-start', {})

        @logger.info("Starting instance #{@instance}")
        @agent_client.start
      end

      # for backwards compatibility with instances that don't have update config
      if update_config && run_post_start
        min_watch_time = @is_canary ? update_config.min_canary_watch_time : update_config.min_update_watch_time
        max_watch_time = @is_canary ? update_config.max_canary_watch_time : update_config.max_update_watch_time

        post_start(min_watch_time, max_watch_time)
      end
    end

    private

    def post_start(min_watch_time, max_watch_time)
      current_state = wait_until_desired_state(min_watch_time, max_watch_time)

      if @instance.state == 'started'
        if current_state['job_state'] != 'running'
          failing_jobs = Array(current_state['processes']).map do |process|
            process['name'] if process['state'] != 'running'
          end.compact

          error_message = "'#{@instance}' is not running after update."
          error_message += " Review logs for failed jobs: #{failing_jobs.join(", ")}" if !failing_jobs.empty?

          raise AgentJobNotRunning, error_message
        else
          @logger.info("Running post-start for #{@instance}")
          @agent_client.run_script('post-start', {})
        end
      end

      if @instance.state == 'stopped' && current_state['job_state'] == 'running'
        raise AgentJobNotStopped, "'#{@instance}' is still running despite the stop command"
      end

      @instance.update_state
    end

    def wait_until_desired_state(min_watch_time, max_watch_time)
      current_state = {}
      watch_schedule(min_watch_time, max_watch_time).each do |watch_time|
        begin
          sleep_time = watch_time.to_f / 1000
          Config.job_cancelled?
          @logger.info("Waiting for #{sleep_time} seconds to check #{@instance} status")
          sleep(sleep_time)
          @logger.info("Checking if #{@instance} has been updated after #{sleep_time} seconds")

          current_state = @agent_client.get_state

          if @instance.state == 'started'
            break if current_state['job_state'] == 'running'
          elsif @instance.state == 'stopped'
            break if current_state['job_state'] != 'running'
          end
        rescue Bosh::Director::TaskCancelled
          @logger.debug("Task was cancelled. Stop waiting for the desired state")
          raise
        end
      end

      current_state
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
