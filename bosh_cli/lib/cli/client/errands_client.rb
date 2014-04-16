module Bosh::Cli::Client
  class ErrandsClient
    class ErrandResult
      attr_reader :exit_code, :stdout, :stderr

      def initialize(exit_code, stdout, stderr)
        @exit_code = exit_code
        @stdout = stdout
        @stderr = stderr
      end

      def ==(other)
        unless other.is_a?(self.class)
          raise ArgumentError, "Must be #{self.class} to compare"
        end
        [exit_code, stdout, stderr] == [other.exit_code, other.stdout, other.stderr]
      end
    end

    def initialize(director)
      @director = director
    end

    def run_errand(deployment_name, errand_name)
      url = "/deployments/#{deployment_name}/errands/#{errand_name}/runs"
      options = { content_type: 'application/json', payload: '{}' }

      status, task_id = @director.request_and_track(:post, url, options)

      unless [:done, :cancelled].include?(status)
        return [status, task_id, nil]
      end

      task_result = JSON.parse(@director.get_task_result_log(task_id))
      errand_result = ErrandResult.new(*task_result.values_at('exit_code', 'stdout', 'stderr'))

      [status, task_id, errand_result]
    end
  end
end
