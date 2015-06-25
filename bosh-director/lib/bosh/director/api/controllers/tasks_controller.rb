require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class TasksController < BaseController
      get '/', scope: :read do
        dataset = Models::Task.dataset

        if limit = params['limit']
          limit = limit.to_i
          limit = 1 if limit < 1
          dataset = dataset.limit(limit)
        end

        states = params['state'].to_s.split(',')
        if states.size > 0
          dataset = dataset.filter(:state => states)
        end

        verbose = params['verbose'] || '1'
        if verbose == '1'
          dataset = dataset.filter(type: %w[
            create_snapshot
            delete_deployment
            delete_release
            delete_snapshot
            delete_stemcell
            run_errand
            snapshot_deployment
            update_deployment
            update_release
            update_stemcell
          ])
        end

        tasks = dataset.order_by(:timestamp.desc).map do |task|
          if task_timeout?(task)
            task.state = :timeout
            task.save
          end
          @task_manager.task_to_hash(task)
        end

        content_type(:json)
        json_encode(tasks)
      end

      get '/:id', scope: :read do
        task = @task_manager.find_task(params[:id])
        if task_timeout?(task)
          task.state = :timeout
          task.save
        end

        content_type(:json)
        json_encode(@task_manager.task_to_hash(task))
      end

      # Sends back output of given task id and params[:type]
      # Example: `get /tasks/5/output?type=event` will send back the file
      # at /var/vcap/store/director/tasks/5/event
      get '/:id/output', scope: Api::Extensions::Scoping::ParamsScope.new(:type, {event: :read, result: :read}) do
        log_type = params[:type] || 'debug'
        task = @task_manager.find_task(params[:id])

        if task.output.nil?
          halt(204)
        end

        log_file = @task_manager.log_file(task, log_type)

        if File.file?(log_file)
          send_file(log_file, :type => 'text/plain')
        else
          status(204)
        end
      end

      private

      def task_timeout?(task)
        # Some of the old task entries might not have the checkpoint_time
        unless task.checkpoint_time
          task.checkpoint_time = Time.now
          task.save
        end

        # If no checkpoint update in 3 cycles --> timeout
        (task.state == 'processing' || task.state == 'cancelling') &&
          (Time.now - task.checkpoint_time > Config.task_checkpoint_interval * 3)
      end
    end
  end
end
