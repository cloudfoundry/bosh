require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DeploymentsController < BaseController
      get '/deployments/:deployment/jobs/:job/:index' do
        instance = @instance_manager.find_by_name(params[:deployment], params[:job], params[:index])

        response = {
          deployment: params[:deployment],
          job: instance.job,
          index: instance.index,
          state: instance.state,
          disks: instance.persistent_disks.map {|d| d.disk_cid}
        }

        json_encode(response)
      end

      # PUT /deployments/foo/jobs/dea?new_name=dea_new
      put '/deployments/:deployment/jobs/:job', :consumes => :yaml do
        if params['state']
          options = {
            'job_states' => {
              params[:job] => {
                'state' => params['state']
              }
            }
          }
        else
          unless params['new_name']
            raise DirectorError, "Missing operation on job `#{params[:job]}'"
          end
          options = {
            'job_rename' => {
              'old_name' => params[:job],
              'new_name' => params['new_name']
            }
          }
          options['job_rename']['force'] = true if params['force'] == 'true'
        end

        # we get the deployment here even though it isn't used here, to make sure
        # the call returns a 404 if the deployment doesn't exist
        @deployment_manager.find_by_name(params[:deployment])
        task = @deployment_manager.create_deployment(@user, request.body, options)
        redirect "/tasks/#{task.id}"
      end

      # PUT /deployments/foo/jobs/dea/2?state={started,stopped,detached,restart,recreate}
      put '/deployments/:deployment/jobs/:job/:index', :consumes => :yaml do
        begin
          index = Integer(params[:index])
        rescue ArgumentError
          raise InstanceInvalidIndex, "Invalid instance index `#{params[:index]}'"
        end

        options = {
          'job_states' => {
            params[:job] => {
              'instance_states' => {
                index => params['state']
              }
            }
          }
        }

        deployment = @deployment_manager.find_by_name(params[:deployment])
        manifest = request.content_length.nil? ? StringIO.new(deployment.manifest) : request.body
        task = @deployment_manager.create_deployment(@user, manifest, options)
        redirect "/tasks/#{task.id}"
      end

      # GET /deployments/foo/jobs/dea/2/logs
      get '/deployments/:deployment/jobs/:job/:index/logs' do
        deployment = params[:deployment]
        job = params[:job]
        index = params[:index]

        options = {
          'type' => params[:type].to_s.strip,
          'filters' => params[:filters].to_s.strip.split(/[\s\,]+/)
        }

        task = @instance_manager.fetch_logs(@user, deployment, job, index, options)
        redirect "/tasks/#{task.id}"
      end

      get '/deployments/:deployment/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        json_encode(@snapshot_manager.snapshots(deployment))
      end

      get '/deployments/:deployment/jobs/:job/:index/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        json_encode(@snapshot_manager.snapshots(deployment, params[:job], params[:index]))
      end

      post '/deployments/:deployment/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        # until we can tell the agent to flush and wait, all snapshots are considered dirty
        options = {clean: false}

        task = @snapshot_manager.create_deployment_snapshot_task(@user, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      put '/deployments/:deployment/jobs/:job/:index/resurrection', consumes: :json do
        payload = json_decode(request.body)

        @resurrector_manager.set_pause_for_instance(params[:deployment], params[:job], params[:index], payload['resurrection_paused'])
      end

      post '/deployments/:deployment/jobs/:job/:index/snapshots' do
        instance = @instance_manager.find_by_name(params[:deployment], params[:job], params[:index])
        # until we can tell the agent to flush and wait, all snapshots are considered dirty
        options = {clean: false}

        task = @snapshot_manager.create_snapshot_task(@user, instance, options)
        redirect "/tasks/#{task.id}"
      end

      delete '/deployments/:deployment/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])

        task = @snapshot_manager.delete_deployment_snapshots_task(@user, deployment)
        redirect "/tasks/#{task.id}"
      end

      delete '/deployments/:deployment/snapshots/:cid' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        snapshot = @snapshot_manager.find_by_cid(deployment, params[:cid])

        task = @snapshot_manager.delete_snapshots_task(@user, [params[:cid]])
        redirect "/tasks/#{task.id}"
      end

      get '/deployments' do
        deployments = Models::Deployment.order_by(:name.asc).map { |deployment|
          name = deployment.name

          releases = deployment.release_versions.map { |rv|
            Hash['name', rv.release.name, 'version', rv.version.to_s]
          }

          stemcells = deployment.stemcells.map { |sc|
            Hash['name', sc.name, 'version', sc.version]
          }

          Hash['name', name, 'releases', releases, 'stemcells', stemcells]
        }

        json_encode(deployments)
      end

      get '/deployments/:name' do
        deployment = @deployment_manager.find_by_name(params[:name])
        @deployment_manager.deployment_to_json(deployment)
      end

      get '/deployments/:name/vms' do
        deployment = @deployment_manager.find_by_name(params[:name])

        format = params[:format]
        if format == 'full'
          task = @vm_state_manager.fetch_vm_state(@user, deployment, format)
          redirect "/tasks/#{task.id}"
        else
          @deployment_manager.deployment_vms_to_json(deployment)
        end
      end

      delete '/deployments/:name' do
        deployment = @deployment_manager.find_by_name(params[:name])

        options = {}
        options['force'] = true if params['force'] == 'true'
        options['keep_snapshots'] = true if params['keep_snapshots'] == 'true'
        task = @deployment_manager.delete_deployment(@user, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      # Property management
      get '/deployments/:deployment/properties' do
        properties = @property_manager.get_properties(params[:deployment]).map do |property|
          { 'name' => property.name, 'value' => property.value }
        end
        json_encode(properties)
      end

      get '/deployments/:deployment/properties/:property' do
        property = @property_manager.get_property(params[:deployment], params[:property])
        json_encode('value' => property.value)
      end

      post '/deployments/:deployment/properties', :consumes => [:json] do
        payload = json_decode(request.body)
        @property_manager.create_property(params[:deployment], payload['name'], payload['value'])
        status(204)
      end

      post '/deployments/:deployment/ssh', :consumes => [:json] do
        payload = json_decode(request.body)
        task = @instance_manager.ssh(@user, payload)
        redirect "/tasks/#{task.id}"
      end

      put '/deployments/:deployment/properties/:property', :consumes => [:json] do
        payload = json_decode(request.body)
        @property_manager.update_property(params[:deployment], params[:property], payload['value'])
        status(204)
      end

      delete '/deployments/:deployment/properties/:property' do
        @property_manager.delete_property(params[:deployment], params[:property])
        status(204)
      end

      # Cloud check

      # Initiate deployment scan
      post '/deployments/:deployment/scans' do
        start_task { @problem_manager.perform_scan(@user, params[:deployment]) }
      end

      # Get the list of problems for a particular deployment
      get '/deployments/:deployment/problems' do
        problems = @problem_manager.get_problems(params[:deployment]).map do |problem|
          {
            'id' => problem.id,
            'type' => problem.type,
            'data' => problem.data,
            'description' => problem.description,
            'resolutions' => problem.resolutions
          }
        end

        json_encode(problems)
      end

      # Try to resolve a set of problems
      put '/deployments/:deployment/problems', :consumes => [:json] do
        payload = json_decode(request.body)
        start_task { @problem_manager.apply_resolutions(@user, params[:deployment], payload['resolutions']) }
      end

      put '/deployments/:deployment/scan_and_fix', :consumes => :json do
        jobs_json = json_decode(request.body)['jobs']
        # payload: [['j1', 'i1'], ['j1', 'i2'], ['j2', 'i1'], ...]
        payload = convert_job_instance_hash(jobs_json)

        start_task { @problem_manager.scan_and_fix(@user, params[:deployment], payload) }
      end

      post '/deployments', :consumes => :yaml do
        options = {}
        options['recreate'] = true if params['recreate'] == 'true'

        task = @deployment_manager.create_deployment(@user, request.body, options)
        redirect "/tasks/#{task.id}"
      end
    end
  end
end
