require 'membrane'

module Bosh::Director
  class Errand::Runner
    class ErrandResult
      attr_reader :exit_code

      AGENT_TASK_RESULT_SCHEMA = ::Membrane::SchemaParser.parse do
        {
          'exit_code' => Integer,
          'stdout' => String,
          'stderr' => String,
        }
      end

      # Explicitly write out schema of the director task result
      # to avoid accidently leaking agent task result extra fields.
      def self.from_agent_task_result(agent_task_result)
        AGENT_TASK_RESULT_SCHEMA.validate(agent_task_result)
        new(*agent_task_result.values_at('exit_code', 'stdout', 'stderr'))
      rescue Membrane::SchemaValidationError => e
        raise AgentInvalidTaskResult, e.message
      end

      def initialize(exit_code, stdout, stderr)
        @exit_code = exit_code
        @stdout = stdout
        @stderr = stderr
      end

      def to_hash
        {
          'exit_code' => @exit_code,
          'stdout' => @stdout,
          'stderr' => @stderr,
        }
      end
    end

    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Director::TaskResultFile] result_file
    # @param [Bosh::Director::EventLog::Log] event_log
    def initialize(job, result_file, instance_manager, event_log)
      @job = job
      @result_file = result_file
      @instance_manager = instance_manager
      @event_log = event_log
    end

    # Runs errand on job instances
    # @return [String] short description of the errand result
    def run(&blk)
      instance = @job.instances.first
      unless instance
        raise DirectorError, 'Must have at least one job instance to run an errand'
      end

      agent_task_result = nil

      event_log_stage = @event_log.begin_stage('Running errand', 1)
      event_log_stage.advance_and_track("#{@job.name}/#{instance.index}") do
        agent = @instance_manager.agent_client_for(instance.model)
        agent_task_result = agent.run_errand(&blk)
      end

      errand_result = ErrandResult.from_agent_task_result(agent_task_result)
      @result_file.write(JSON.dump(errand_result.to_hash) + "\n")

      title_prefix = "Errand `#{@job.name}' completed"
      exit_code_suffix = "(exit code #{errand_result.exit_code})"

      if errand_result.exit_code == 0
        "#{title_prefix} successfully #{exit_code_suffix}"
      else
        "#{title_prefix} with error #{exit_code_suffix}"
      end
    end

    def cancel
    end
  end
end
