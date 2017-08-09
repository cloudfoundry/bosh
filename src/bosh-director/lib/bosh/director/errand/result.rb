require 'membrane'

module Bosh::Director
  class Errand::Result
    attr_reader :exit_code

    AGENT_RUN_ERRAND_RESULT_SCHEMA = ::Membrane::SchemaParser.parse do
      {
        'exit_code' => Integer,
        'stdout' => String,
        'stderr' => String,
      }
    end

    # Explicitly write out schema of the director task result
    # to avoid accidently leaking agent task result extra fields.
    def self.from_agent_task_results(errand_name, agent_task_result, logs_blobstore_id, logs_blob_sha1 = nil)
      AGENT_RUN_ERRAND_RESULT_SCHEMA.validate(agent_task_result)
      new(errand_name, *agent_task_result.values_at('exit_code', 'stdout', 'stderr'), logs_blobstore_id, logs_blob_sha1)
    rescue Membrane::SchemaValidationError => e
      raise AgentInvalidTaskResult, e.message
    end

    def initialize(errand_name, exit_code, stdout, stderr, logs_blobstore_id, logs_blob_sha1 = nil)
      @errand_name = errand_name
      @exit_code = exit_code
      @stdout = stdout
      @stderr = stderr
      @logs_blobstore_id = logs_blobstore_id
      @logs_blob_sha1 = logs_blob_sha1
    end

    def to_hash
      {
        'errand_name' => @errand_name,
        'exit_code' => @exit_code,
        'stdout' => @stdout,
        'stderr' => @stderr,
        'logs' => {
          'blobstore_id' => @logs_blobstore_id,
          'sha1' => @logs_blob_sha1,
        },
      }
    end

    def cancelled?
      @exit_code > 128
    end

    def errored?
      @exit_code > 0 && @exit_code <= 128
    end

    def successful?
      @exit_code == 0
    end
  end
end
