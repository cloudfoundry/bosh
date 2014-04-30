require 'membrane'

module Bosh::Director
  class Errand::Result
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
end
