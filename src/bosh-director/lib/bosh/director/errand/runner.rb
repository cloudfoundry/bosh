module Bosh::Director
  class Errand::Runner
    # @param [String] errand_name
    # @param [Boolean] errand_is_job_name
    # @param [Bosh::Director::TaskDBWriter] task_result
    # @param [Bosh::Director::Api::InstanceManager] instance_manager
    # @param [Bosh::Director::LogsFetcher] logs_fetcher
    def initialize(errand_name, errand_is_job_name, task_result, instance_manager, logs_fetcher)
      @errand_name = errand_name
      @errand_is_job_name = errand_is_job_name
      @task_result = task_result
      @instance_manager = instance_manager
      @agent_task_id = nil
      @logs_fetcher = logs_fetcher
    end

    # Runs errand on job instances
    # @return [String] short description of the errand result
    def run(instance, &checkpoint_block)
      agent = @instance_manager.agent_client_for(instance.model)

      if @errand_is_job_name
        info_response = agent.info

        if info_response['api_version'] < 1
          if @errand_name != instance.model.spec['job']['template']
            raise DirectorError, "Multiple jobs are configured on an older stemcell, and \"#{@errand_name}\" is not the first job"
          end
        end
      end

      errand_run = Models::ErrandRun.find_or_create(instance_id: instance.model.id)
      errand_run.update(successful: false,
        successful_configuration_hash: '',
        successful_packages_spec: ''
      )

      agent_task_result = nil
      event_log_stage = Config.event_log.begin_stage('Running errand', 1)
      agent_task_id = nil

      begin
        event_log_stage.advance_and_track(instance.to_s) do
          if @errand_is_job_name
            run_errand_result = agent.run_errand(@errand_name)
          else
            run_errand_result = agent.run_errand
          end

          agent_task_id = run_errand_result['agent_task_id']
          agent_task_result = agent.wait_for_task(agent_task_id, &cancel_block(checkpoint_block, agent, agent_task_id))
        end
      rescue TaskCancelled => e
        # Existing run_errand long running task will return a result
        # after agent cancels the task
        agent_task_result = agent.wait_for_task(agent_task_id)
        cancel_error = e
      end

      begin
        logs_blobstore_id, logs_blobstore_sha1 = @logs_fetcher.fetch(instance.model, 'job', nil, true)
      rescue DirectorError => e
        fetch_logs_error = e
      end

      if agent_task_result
        errand_result = Errand::Result.from_agent_task_results(agent_task_result, logs_blobstore_id, logs_blobstore_sha1)
        @task_result.write(JSON.dump(errand_result.to_hash) + "\n")
      end

      if errand_result && errand_result.exit_code == 0
        errand_run.update(
          successful: true,
          successful_configuration_hash: instance.configuration_hash,
          successful_packages_spec: JSON.dump(instance.current_packages)
        )
      end

      # Prefer to raise cancel error because
      # it was triggered before trying to fetch logs
      raise cancel_error if cancel_error

      raise fetch_logs_error if fetch_logs_error

      errand_result
    end

    private

    def cancel_block(checkpoint_block, agent, agent_task_id)
      lambda do
        begin
          checkpoint_block.call
        rescue TaskCancelled => e
          agent.cancel_task(agent_task_id)
          raise e
        end
      end
    end
  end
end
