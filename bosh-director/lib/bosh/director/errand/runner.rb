module Bosh::Director
  class Errand::Runner
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Director::TaskResultFile] result_file
    # @param [Bosh::Director::Api::InstanceManager] instance_manager
    # @param [Bosh::Director::EventLog::Log] event_log
    # @param [Bosh::Director::LogsFetcher] logs_fetcher
    def initialize(job, result_file, instance_manager, event_log, logs_fetcher)
      @job = job
      @result_file = result_file
      @instance_manager = instance_manager
      @event_log = event_log
      @agent_task_id = nil
      @logs_fetcher = logs_fetcher
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
          run_errand_result = agent.run_errand
          @agent_task_id = run_errand_result['agent_task_id']
          agent_task_result = agent.wait_for_task(agent_task_id, &blk)
        end
      rescue TaskCancelled => e
        # Existing run_errand long running task will return a result
        # after agent cancels the task
        agent_task_result = agent.wait_for_task(agent_task_id)
        @cancel_error = e
      end

      begin
        logs_blobstore_id = @logs_fetcher.fetch(instance.model, 'job', nil)
      rescue DirectorError => e
        @fetch_logs_error = e
      end

      if agent_task_result
        errand_result = Errand::Result.from_agent_task_results(agent_task_result, logs_blobstore_id)
        @result_file.write(JSON.dump(errand_result.to_hash) + "\n")
      end

      # Prefer to raise cancel error because
      # it was triggered before trying to fetch logs
      raise @cancel_error if @cancel_error

      raise @fetch_logs_error if @fetch_logs_error

      errand_result.short_description(@job.name)
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
