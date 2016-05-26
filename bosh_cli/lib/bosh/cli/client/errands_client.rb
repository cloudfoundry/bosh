require 'multi_json'

module Bosh::Cli::Client
  class ErrandsClient
    class ErrandResult
      attr_reader :exit_code, :stdout, :stderr, :logs_blobstore_id

      def initialize(exit_code, stdout, stderr, logs_blobstore_id)
        @exit_code = exit_code
        @stdout = stdout
        @stderr = stderr
        @logs_blobstore_id = logs_blobstore_id
      end

      def ==(other)
        unless other.is_a?(self.class)
          raise ArgumentError, "Must be #{self.class} to compare"
        end

        local = [exit_code, stdout, stderr, logs_blobstore_id]
        other = [other.exit_code, other.stdout, other.stderr, other.logs_blobstore_id]
        local == other
      end
    end

    def initialize(director)
      @director = director
    end

    def run_errand(deployment_name, errand_name, keep_alive)
      url = "/deployments/#{deployment_name}/errands/#{errand_name}/runs"
      payload = MultiJson.encode({'keep-alive' => (keep_alive || FALSE)})
      options = { content_type: 'application/json', payload: payload }

      status, task_id = @director.request_and_track(:post, url, options)

      unless [:done, :cancelled].include?(status)
        return [status, task_id, nil]
      end

      errand_result_output = @director.get_task_result_log(task_id)
      errand_result = nil

      if errand_result_output
        task_result = JSON.parse(errand_result_output)
        errand_result = ErrandResult.new(
          *task_result.values_at('exit_code', 'stdout', 'stderr'),
          task_result.fetch('logs', {})['blobstore_id'],
        )
      end

      [status, task_id, errand_result]
    end
  end
end
