module Bosh::Director
  module Jobs
    class DBJob
      attr_reader :job_class, :task_id

      def initialize(job_class, task_id, args)
        unless job_class.kind_of?(Class) &&
          job_class <= Jobs::BaseJob
          raise DirectorError, "Invalid director job class `#{job_class}'"
        end
        raise DirectorError, "Invalid director job class `#{job_class}'. It should have `perform' method." unless job_class.instance_methods(false).include?(:perform)
        @job_class = job_class
        @task_id = task_id
        @args = args
        raise DirectorError, "Invalid director job class `#{job_class}'. It should specify queue value." unless queue_name
      end

      def before(job)
        @worker_name = job.locked_by
      end

      def perform
        Config.db.transaction(:retry_on => [Sequel::DatabaseConnectionError]) do
          if Models::Task.where(id: @task_id, state: 'queued').update(state: 'processing') != 1
            raise DirectorError, "Cannot perform job for task #{@task_id} (not in 'queued' state)"
          end
        end

        process_status = ForkedProcess.run do
          perform_args = []

          unless @args.nil?
            perform_args = decode(encode(@args))
          end

          @job_class.perform(@task_id, @worker_name, *perform_args)
        end

        if process_status.signaled?
          Config.logger.debug("Task #{@task_id} was terminated, marking as failed")
          fail_task
        end
      end

      def queue_name
        if (@job_class.instance_variable_get(:@local_fs) ||
          (@job_class.respond_to?(:local_fs) && @job_class.local_fs)) && !Config.director_pool.nil?
          Config.director_pool
        else
          @job_class.instance_variable_get(:@queue) ||
            (@job_class.respond_to?(:queue) && @job_class.queue)
        end
      end

      private

      def fail_task
        Models::Task.first(id: @task_id).update(state: 'error')
      end

      def encode(object)
        JSON.generate object
      end

      # Given a string, returns a Ruby object.
      def decode(object)
        return unless object

        begin
          JSON.parse object
        rescue JSON::ParserError => e
          raise DecodeException, e.message, e.backtrace
        end
      end
    end
  end

  class ForkedProcess
    def self.run
      pid = Process.fork do
        begin
          EM.run do
            operation = proc { yield }
            operation_complete_callback = proc { EM.stop }
            EM.defer( operation, operation_complete_callback )
          end
        rescue Exception => e
          Config.logger.error("Fatal error from event machine: #{e}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end
      Process.waitpid(pid)

      $?
    end
  end
end
