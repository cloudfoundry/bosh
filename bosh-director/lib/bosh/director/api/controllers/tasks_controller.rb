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
            check_access_to_task(task, :admin)
          elsif type == 'event' || type == 'result' || type == 'none'
            check_access_to_task(task, :read)
          else
            raise UnauthorizedToAccessDeployment, "Unknown type #{type}"
          end
        end
      end

      get '/', scope: :list_tasks do
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
            attach_disk
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

        deployment = params['deployment']
        if deployment
          dataset = dataset.filter(deployment_name: deployment)
          deployment = @deployment_manager.find_by_name(deployment)
          @permission_authorizer.granted_or_raise(deployment, :read, token_scopes)
        end

        tasks = dataset.order_by(Sequel.desc(:timestamp)).map

        unless @permission_authorizer.is_granted?(:director, :read, token_scopes)
          permitted_deployments = @deployment_manager.all_by_name_asc.select { |deployment|
              @permission_authorizer.is_granted?(deployment, :read, token_scopes)
            }.map { |deployment| deployment.name }

          tasks = tasks.select do |task|
            next false unless task.deployment_name
            permitted_deployments.include?(task.deployment_name)
          end
        end

        tasks = tasks.map do |task|
          if task_timeout?(task)
            task.state = :timeout
            task.save
          end
          @task_manager.task_to_hash(task)
        end
        content_type(:json)
        json_encode(tasks)
      end

      get '/:id', scope: :list_tasks do
        task = @task_manager.find_task(params[:id])
        deployment_name = task.deployment_name
        if deployment_name
          check_access_to_deployment(deployment_name, :read)
        elsif !@permission_authorizer.is_granted?(:director, :read, token_scopes)
          raise UnauthorizedToAccessDeployment,
            'One of the following scopes is required to access this task: ' +
              @permission_authorizer.list_expected_scope(:director, :read, token_scopes).join(', ')
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

        if File.file?(log_file)
          send_file(log_file, :type => 'text/plain')
        else
          status(204)
        end
      end

      private

      def check_access_to_task(task, scope)
        if task.deployment_name
          check_access_to_deployment(task.deployment_name, scope)
        else
          @permission_authorizer.granted_or_raise(:director, scope, token_scopes)
        end
      end

      def check_access_to_deployment(deployment_name, scope)
        begin
          deployment = @deployment_manager.find_by_name(deployment_name)
          @permission_authorizer.granted_or_raise(deployment, scope, token_scopes)
        rescue DeploymentNotFound
          @permission_authorizer.granted_or_raise(:director, :admin, token_scopes)
        end
      end

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
