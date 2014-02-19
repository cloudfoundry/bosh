require 'membrane'

module Bosh::Director
  module Jobs
    class RunErrand < BaseJob
      @queue = :normal

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

        director_task_result = extract_director_task_result(agent_task_result)
        result_file.write(JSON.dump(director_task_result) + "\n")
      end

      private

      AGENT_TASK_RESULT_SCHEMA = ::Membrane::SchemaParser.parse do
        { 'exit_code' => Integer,
          'stdout' => String,
          'stderr' => String,
        }
      end

      # Explicitly write out schema of the director task result
      # to avoid accidently leaking agent task result extra fields.
      def extract_director_task_result(agent_task_result)
        AGENT_TASK_RESULT_SCHEMA.validate(agent_task_result)
        {
          'exit_code' => agent_task_result['exit_code'],
          'stdout' => agent_task_result['stdout'],
          'stderr' => agent_task_result['stderr'],
        }
      rescue Membrane::SchemaValidationError => e
        raise AgentInvalidTaskResult, e.message
      end
    end
  end
end
