require 'membrane'

module Bosh::Director
  module Jobs
    class RunErrand < BaseJob
      @queue = :normal

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

      def self.job_type
        :run_errand
      end

      def initialize(deployment_name, errand_name)
        @deployment_name = deployment_name
        @errand_name = errand_name
        @instance_manager = Api::InstanceManager.new
      end

      def perform
        instance = @instance_manager.find_by_name(@deployment_name, @errand_name, 0)

        agent = @instance_manager.agent_client_for(instance)
        agent_task_result = agent.run_errand

        errand_result = ErrandResult.from_agent_task_result(agent_task_result)
        result_file.write(JSON.dump(errand_result.to_hash) + "\n")

        title_prefix = "Errand `#{@errand_name}' completed"
        exit_code_suffix = "(exit code #{errand_result.exit_code})"

        if errand_result.exit_code == 0
          "#{title_prefix} successfully #{exit_code_suffix}"
        else
          "#{title_prefix} with error #{exit_code_suffix}"
        end
      end
    end
  end
end
