module Bosh::Director
  class Errand::Runner
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Director::TaskResultFile] result_file
    # @param [Bosh::Director::EventLog::Log] event_log
    def initialize(job, result_file, instance_manager, event_log)
      @job = job
      @result_file = result_file
      @instance_manager = instance_manager
      @event_log = event_log
      @agent_task_id = nil
    end

    # Runs errand on job instances
    # @return [String] short description of the errand result
    def run(&blk)
      unless instance
        raise DirectorError, 'Must have at least one job instance to run an errand'
      end

      agent_task_result = nil

      event_log_stage = @event_log.begin_stage('Running errand', 1)
      begin
        event_log_stage.advance_and_track("#{@job.name}/#{instance.index}") do
          start_errand_result = agent.start_errand
          @agent_task_id = start_errand_result['agent_task_id']
          agent_task_result = agent.wait_for_task(agent_task_id, &blk)
        end
      rescue TaskCancelled => e
        agent_task_result = agent.wait_for_task(agent_task_id)
        raise e
      ensure
        if agent_task_result
          errand_result = Errand::Result.from_agent_task_result(agent_task_result)
          @result_file.write(JSON.dump(errand_result.to_hash) + "\n")
        end
      end

      title_prefix = "Errand `#{@job.name}'"
      exit_code_suffix = "(exit code #{errand_result.exit_code})"

      if errand_result.exit_code == 0
        "#{title_prefix} completed successfully #{exit_code_suffix}"
      elsif errand_result.exit_code > 128
        "#{title_prefix} was canceled #{exit_code_suffix}"
      else
        "#{title_prefix} completed with error #{exit_code_suffix}"
      end
    end

    def cancel
      agent.cancel_task(agent_task_id) if agent_task_id
    end

    private

    attr_reader :agent_task_id

    def agent
      @agent ||= @instance_manager.agent_client_for(instance.model)
    end

    def instance
      @instance ||= @job.instances.first
    end
  end
end
