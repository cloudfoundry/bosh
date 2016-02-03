module Bosh::Director
  module Jobs
    class DBJob
      attr_reader :job_class, :task_id

      def initialize(job_class, task_id, args)
        unless job_class.kind_of?(Class) &&
            job_class <= Jobs::BaseJob
          raise DirectorError, "Invalid director job class `#{job_class}'"
        end
        raise DirectorError, "Invalid director job class `#{job_class}'. It should have `perform' method."  unless job_class.instance_methods(false).include?(:perform)
        @job_class = job_class
        @task_id = task_id
        @args = args
        @logger = Config.logger
        raise DirectorError, "Invalid director job class `#{job_class}'. It should specify queue value." unless queue_name
      end

      def perform
        if Models::Task.first(id: @task_id, state: 'queued').nil?
          raise DirectorError, "Cannot perform job for task #{@task_id} (not in 'queued' state)"
        end

        process_status = ForkedProcess.run do
          @job_class.perform(@task_id, *decode(encode(@args)))
        end

        if process_status.signaled?
          @logger.debug("Task #{@task_id} was terminated, marking as failed")
          fail_task
        end
      end

      def queue_name
        @job_class.instance_variable_get(:@queue) ||
            (@job_class.respond_to?(:queue) and @job_class.queue)
      end

      private

      def fail_task
        Models::Task.first(id: @task_id).update(state: 'error')
      end

      def encode(object)
        if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
          MultiJson.dump object
        else
          MultiJson.encode object
        end
      end

      # Given a string, returns a Ruby object.
      def decode(object)
        return unless object

        begin
          if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
            MultiJson.load object
          else
            MultiJson.decode object
          end
        rescue ::MultiJson::DecodeError => e
          raise DecodeException, e.message, e.backtrace
        end
      end
    end
  end

  class ForkedProcess
    def self.run
      pid = Process.fork do
        EM.error_handler { |e| puts ("Error raised during event loop: #{e.inspect}, backtrace: #{e.backtrace}") }

        # Starting EM for NATS
        Thread.new { EM.run }

        # EM.defer + check defers_finished? to validate that all EM events finished
        EM.defer { yield }
        until EM.reactor_running? && EM.defers_finished?
          sleep 0.5
        end

        EM.stop
        exit
      end

      Process.waitpid(pid)

      $?
    end
  end
end
