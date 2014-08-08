require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class TasksController < BaseController
      get '/' do
        dataset = Models::Task.dataset
        limit = params['limit']
        if limit
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
          update_deployment
          delete_deployment
          update_release
          delete_release
          update_stemcell
          delete_stemcell
          create_snapshot
          delete_snapshot
          snapshot_deployment
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

      get '/:id' do
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
      get '/:id/output' do
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
    end
  end
end
