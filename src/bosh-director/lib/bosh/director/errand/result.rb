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
    def self.from_agent_task_results(agent_task_result, logs_blobstore_id, logs_blob_sha1 = nil)
      AGENT_RUN_ERRAND_RESULT_SCHEMA.validate(agent_task_result)
      new(*agent_task_result.values_at('exit_code', 'stdout', 'stderr'), logs_blobstore_id, logs_blob_sha1)
    rescue Membrane::SchemaValidationError => e
      raise AgentInvalidTaskResult, e.message
    end

    def initialize(exit_code, stdout, stderr, logs_blobstore_id, logs_blob_sha1 = nil)
      @exit_code = exit_code
      @stdout = stdout
      @stderr = stderr
      @logs_blobstore_id = logs_blobstore_id
      @logs_blob_sha1 = logs_blob_sha1
    end

    def short_description(job_name)
      title_prefix = "Errand '#{job_name}'"
      exit_code_suffix = "(exit code #{@exit_code})"

      if @exit_code == 0
        "#{title_prefix} completed successfully #{exit_code_suffix}"
      elsif @exit_code > 128
        "#{title_prefix} was canceled #{exit_code_suffix}"
      else
        "#{title_prefix} completed with error #{exit_code_suffix}"
      end
    end

    def to_hash
      {
        'exit_code' => @exit_code,
        'stdout' => @stdout,
        'stderr' => @stderr,
        'logs' => {
          'blobstore_id' => @logs_blobstore_id,
          'sha1' => @logs_blob_sha1,
        },
      }
    end
  end
end
