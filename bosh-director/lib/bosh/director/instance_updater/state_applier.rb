module Bosh::Director
  class InstanceUpdater::StateApplier
    def initialize(instance_plan, agent_client, rendered_job_templates_cleaner, logger)
      @instance_plan = instance_plan
      @instance = @instance_plan.instance
      @agent_client = agent_client
      @rendered_job_templates_cleaner = rendered_job_templates_cleaner
      @logger = logger
    end

    def apply
      @instance.apply_vm_state(@instance_plan.spec)
      @instance.update_templates(@instance_plan.templates)
      @rendered_job_templates_cleaner.clean

      if @instance.state == 'started'
        @agent_client.run_script('pre-start', {})
        @agent_client.start
      end
    end

    def post_start(min_watch_time, max_watch_time)
      current_state = wait_until_desired_state(min_watch_time, max_watch_time)

      if @instance.state == 'started'
        if current_state['job_state'] != 'running'
          raise AgentJobNotRunning, "`#{@instance}' is not running after update"
        else
          @agent_client.run_script('post-start', {})
        end
      end

      if @instance.state == 'stopped' && current_state['job_state'] == 'running'
        raise AgentJobNotStopped, "`#{@instance}' is still running despite the stop command"
      end

      @instance.update_state
    end

    private

    def wait_until_desired_state(min_watch_time, max_watch_time)
      current_state = {}
      watch_schedule(min_watch_time, max_watch_time).each do |watch_time|
        sleep_time = watch_time.to_f / 1000
        @logger.info("Waiting for #{sleep_time} seconds to check #{@instance} status")
        sleep(sleep_time)
        @logger.info("Checking if #{@instance} has been updated after #{sleep_time} seconds")

        current_state = @agent_client.get_state

        if @instance.state == 'started'
          break if current_state['job_state'] == 'running'
        elsif @instance.state == 'stopped'
          break if current_state['job_state'] != 'running'
        end
      end

      current_state
    end

    # Returns an array of wait times distributed
    # on the [min_watch_time..max_watch_time] interval.
    #
    # Tries to respect intervals but doesn't allow an interval to
    # fall under 1 second.
    # All times are in milliseconds.
    # @param [Numeric] min_watch_time minimum time to watch the jobs
    # @param [Numeric] max_watch_time maximum time to watch the jobs
    # @return [Array<Numeric>] watch schedule
    def watch_schedule(min_watch_time, max_watch_time)
      delta = (max_watch_time - min_watch_time).to_f
      watch_intervals = 10
      step = [1000, delta / (watch_intervals - 1)].max

      [min_watch_time] + ([step] * (delta / step).floor)
    end
  end
end
