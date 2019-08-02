module Bosh::Director
  module Api
    class TaskManager
      # Looks up director task in DB
      # @param [Integer] task_id
      # @return [Models::Task] Task
      # @raise [TaskNotFound]
      def find_task(task_id)
        task = Models::Task[task_id]
        raise TaskNotFound, "Task #{task_id} not found" if task.nil?

        task
      end

      def select(selector)
        selector ||= {}

        default_states = ['queued']
        states = selector.fetch('states', default_states)
        states = default_states if !states.is_a?(Array) || states.empty?

        types = selector.fetch('types', [])
        types = [] unless types.is_a?(Array)

        deployment = selector['deployment']

        sql = Models::Task.where(state: states)
        sql = sql.where(type: types) unless types.empty?
        sql = sql.where(deployment_name: deployment) if deployment
        sql.all
      end

      def cancel_tasks(tasks)
        tasks.each do |task|
          begin
            cancel(task)
          rescue TaskUnexpectedState
            Config.logger.info("Cannot cancel task #{task.id}: invalid state (#{task.state})")
          end
        end
      end

      def cancel(task)
        raise TaskUnexpectedState unless task.cancellable?

        task.state = :cancelling
        task.save
      end

      # Returns hash representation of the task
      # @param [Models::Task] task Director task
      # @return [Hash] Hash task representation
      def task_to_hash(task)
        {
          'id' => task.id,
          'state' => task.state,
          'description' => task.description,
          'timestamp' => adjust_task_finish_time(task),
          'started_at' => task.started_at ? task.started_at.to_i : nil,
          'result' => task.result,
          'user' => task.username || 'admin',
          'deployment' => task.deployment_name,
          'context_id' => task.context_id,
        }
      end

      def log_file(task, log_type)
        # Backward compatibility
        return task.output unless File.directory?(task.output)

        file = File.join(task.output, log_type)
        file_gz = [file, 'gz'].join('.')

        decompress(file_gz, file)

        file
      end

      def decompress(src, dst)
        # only decompress if log_file is missing and we have a compressed file
        return unless !File.file?(dst) && File.file?(src)

        File.open(dst, 'w') do |file|
          Zlib::GzipReader.open(src) do |gz|
            file.write gz.read
          end
        end
        FileUtils.rm(src)
      end

      private

      # adjust_task_finish_time will return nil for the `timestamp` field, if the task is still queued or processing
      # This way, the CLI can better translate that we don't have a finish time yet
      def adjust_task_finish_time(task)
        return nil if %w[queued processing].include?(task.state)

        task.timestamp.to_i
      end
    end
  end
end
