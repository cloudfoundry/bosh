require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class TasksController < BaseController

      def initialize(config)
        super(config)
        @deployment_manager = Api::DeploymentManager.new
      end

      def self.authorization(perm)
        return unless perm

        condition do
          type = params[:type]
          task = @task_manager.find_task(params[:id])
          if type == 'debug' || type == 'cpi' || !type
            @permission_authorizer.granted_or_raise(task, :admin, token_scopes)
          elsif type == 'event' || type == 'result' || type == 'none'
            @permission_authorizer.granted_or_raise(task, :read, token_scopes)
          else
            raise UnauthorizedToAccessDeployment, "Unknown type #{type}"
          end
        end
      end

      get '/', scope: :list_tasks do
        dataset = Models::Task.dataset

        states = params['state'].to_s.split(',')
        if states.size > 0
          dataset = dataset.filter(:state => states)
        end

        verbose = params['verbose'] || '1'
        if verbose == '1'
          dataset = dataset.filter(type: %w[
            attach_disk
            create_snapshot
            delete_deployment
            delete_release
            delete_snapshot
            delete_stemcell
            run_errand
            snapshot_deployment
            update_instance
            update_deployment
            update_release
            update_stemcell
            export_release
          ])
        end

        if context_id = params['context_id']
          dataset = dataset.filter(:context_id => context_id)
        end

        if limit = params['limit']
          limit = limit.to_i
          limit = 1 if limit < 1
        end

        if @permission_authorizer.is_granted?(:director, :read, token_scopes) ||
          @permission_authorizer.is_granted?(:director, :admin, token_scopes)
          tasks = filter_task_by_deployment_and_teams(dataset, params['deployment'], nil, limit)
          permitted_tasks = Set.new(tasks)
        else
          tasks = filter_task_by_deployment_and_teams(dataset, params['deployment'], token_scopes, limit)
          permitted_tasks = Set.new(tasks)
        end

        tasks = permitted_tasks.map do |task|
          if task_timeout?(task)
            task.state = :timeout
            task.save
          end
          @task_manager.task_to_hash(task)
        end
        content_type(:json)


        json_encode(tasks)
      end

      def filter_task_by_deployment_and_teams(dataset, deployment, token_scopes, limit)
        if deployment
          dataset = dataset.where(deployment_name: deployment)
        end
        if token_scopes
          teams = Models::Team.transform_admin_team_scope_to_teams(token_scopes)
          dataset = dataset.where(teams: teams)
        end
        if limit
          dataset = dataset.limit(limit)
        end
        dataset.order_by(Sequel.desc(:timestamp)).all
      end


      get '/:id', scope: :list_tasks do
        task = @task_manager.find_task(params[:id])
        if !@permission_authorizer.is_granted?(task, :read, token_scopes)
          raise UnauthorizedToAccessDeployment,
            'One of the following scopes is required to access this task: ' +
              @permission_authorizer.list_expected_scope(task, :read, token_scopes).join(', ')
        end

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
      get '/:id/output', authorization: :task_output, scope: :authorization do
        log_type = params[:type] || 'debug'
        if log_type == "none"
          halt(204)
        end

        task = @task_manager.find_task(params[:id])

        if task.output.nil?
          halt(204)
        end

        log_file = @task_manager.log_file(task, log_type)

        if (['result', 'event'].include? log_type) && (!File.exist?(log_file))
          result = task["#{log_type}_output".to_sym]
          size = result.bytesize
          ranges = Rack::Utils.byte_ranges(env, size)
          if ranges.nil? || ranges.length > 1
            # No ranges, or multiple ranges
            return result
          elsif ranges.empty?
            # Unsatisfiable. Return error, and file size
            response.headers['Content-Range'] = "bytes */#{size}"
            status 416
            body "Byte range unsatisfiable"
            return
          else
            # Partial content:
            range = ranges[0]
            response.headers['Content-Range'] = "bytes #{range.begin}-#{range.end}/#{size}"
            status 206
            body result.byteslice(range)
            return
          end
        end
        if File.file?(log_file)
          send_file(log_file, :type => 'text/plain')
        else
          status(204)
        end
      end

      post '/cancel', consumes: [:json] do
        task_selector = json_decode(request.body.read)

        cancellable_states = %w[queued processing]
        states = task_selector['states'] if task_selector
        states&.each do |state|
          unless cancellable_states.include?(state)
            status(400)
            body "#{state} is not one of the cancellable states: #{cancellable_states.join(', ')}"
            return
          end
        end

        tasks = @task_manager.select(task_selector)
        @task_manager.cancel_tasks(tasks)
        status(204)
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
          (Time.now - task.checkpoint_time > Config.task_checkpoint_interval * 6)
      end
    end
  end
end
