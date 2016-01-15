require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DeploymentsController < BaseController
      get '/:deployment/jobs/:job/:index_or_id' do
        instance = @instance_manager.find_by_name(params[:deployment], params[:job], params[:index_or_id])

        response = {
          deployment: params[:deployment],
          job: instance.job,
          index: instance.index,
          id: instance.uuid,
          state: instance.state,
          disks: instance.persistent_disks.map {|d| d.disk_cid}
        }

        json_encode(response)
      end

      # PUT /deployments/foo/jobs/dea?new_name=dea_new or
      # PUT /deployments/foo/jobs/dea?state={started,stopped,detached,restart,recreate}&skip_drain=true
      put '/:deployment/jobs/:job', :consumes => :yaml do
        options = {
          'job_states' => {
            params[:job] => {
              'state' => params['state']
            }
          }
        }
        options['skip_drain'] = params[:job] if params['skip_drain'] == 'true'

        deployment = @deployment_manager.find_by_name(params[:deployment])
        manifest = ((request.content_length.nil?  || request.content_length.to_i == 0) && (params['state'])) ? StringIO.new(deployment.manifest) : request.body

        latest_cloud_config = Bosh::Director::Api::CloudConfigManager.new.latest
        task = @deployment_manager.create_deployment(current_user, manifest, latest_cloud_config, options)
        redirect "/tasks/#{task.id}"
      end

      # PUT /deployments/foo/jobs/dea/2?state={started,stopped,detached,restart,recreate}&skip_drain=true
      put '/:deployment/jobs/:job/:index_or_id', :consumes => :yaml do
        validate_instance_index_or_id(params[:index_or_id])

        instance = @instance_manager.find_by_name(params[:deployment], params[:job], params[:index_or_id])
        index = instance.index

        options = {
          'job_states' => {
            params[:job] => {
              'instance_states' => {
                index => params['state']
              },
            }
          },
        }
        options['skip_drain'] = params[:job] if params['skip_drain'] == 'true'

        deployment = @deployment_manager.find_by_name(params[:deployment])
        manifest = (request.content_length.nil?  || request.content_length.to_i == 0) ? StringIO.new(deployment.manifest) : request.body
        latest_cloud_config = Bosh::Director::Api::CloudConfigManager.new.latest
        task = @deployment_manager.create_deployment(current_user, manifest, latest_cloud_config, options)
        redirect "/tasks/#{task.id}"
      end

      # GET /deployments/foo/jobs/dea/2/logs
      get '/:deployment/jobs/:job/:index_or_id/logs' do
        deployment = params[:deployment]
        job = params[:job]
        index_or_id = params[:index_or_id]

        options = {
          'type' => params[:type].to_s.strip,
          'filters' => params[:filters].to_s.strip.split(/[\s\,]+/)
        }

        task = @instance_manager.fetch_logs(current_user, deployment, job, index_or_id, options)
        redirect "/tasks/#{task.id}"
      end

      get '/:deployment/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        json_encode(@snapshot_manager.snapshots(deployment))
      end

      get '/:deployment/jobs/:job/:index/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        json_encode(@snapshot_manager.snapshots(deployment, params[:job], params[:index]))
      end

      post '/:deployment/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        # until we can tell the agent to flush and wait, all snapshots are considered dirty
        options = {clean: false}

        task = @snapshot_manager.create_deployment_snapshot_task(current_user, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      put '/:deployment/jobs/:job/:index_or_id/resurrection', consumes: :json do
        payload = json_decode(request.body)

        @resurrector_manager.set_pause_for_instance(params[:deployment], params[:job], params[:index_or_id], payload['resurrection_paused'])
      end

      post '/:deployment/jobs/:job/:index_or_id/snapshots' do
        if params[:index_or_id].to_s =~ /^\d+$/
          instance = @instance_manager.find_by_name(params[:deployment], params[:job], params[:index_or_id])
        else
          instance = @instance_manager.filter_by(uuid: params[:index_or_id]).first
        end
        # until we can tell the agent to flush and wait, all snapshots are considered dirty
        options = {clean: false}

        task = @snapshot_manager.create_snapshot_task(current_user, instance, options)
        redirect "/tasks/#{task.id}"
      end

      delete '/:deployment/snapshots' do
        deployment = @deployment_manager.find_by_name(params[:deployment])

        task = @snapshot_manager.delete_deployment_snapshots_task(current_user, deployment)
        redirect "/tasks/#{task.id}"
      end

      delete '/:deployment/snapshots/:cid' do
        deployment = @deployment_manager.find_by_name(params[:deployment])
        snapshot = @snapshot_manager.find_by_cid(deployment, params[:cid])

        task = @snapshot_manager.delete_snapshots_task(current_user, [params[:cid]])
        redirect "/tasks/#{task.id}"
      end

      get '/', scope: :read do
        latest_cloud_config = Api::CloudConfigManager.new.latest
        deployments = Models::Deployment.order_by(:name.asc).map do |deployment|
        cloud_config = if deployment.cloud_config.nil?
                         'none'
                       elsif deployment.cloud_config == latest_cloud_config
                         'latest'
                       else
                         'outdated'
                       end

          {
            'name' => deployment.name,
            'releases' => deployment.release_versions.map do |rv|
              {
                'name' => rv.release.name,
                'version' => rv.version.to_s
              }
            end,
            'stemcells' => deployment.stemcells.map do |sc|
              {
                'name' => sc.name,
                'version' => sc.version
              }
            end,
            'cloud_config' => cloud_config
          }
        end

        json_encode(deployments)
      end

      get '/:name', scope: :read do
        deployment = @deployment_manager.find_by_name(params[:name])
        @deployment_manager.deployment_to_json(deployment)
      end

      get '/:name/vms', scope: :read do
        deployment = @deployment_manager.find_by_name(params[:name])

        format = params[:format]
        if format == 'full'
          task = @vm_state_manager.fetch_vm_state(current_user, deployment, format)
          redirect "/tasks/#{task.id}"
        else
          @deployment_manager.deployment_instances_to_json(deployment)
        end
      end

      delete '/:name' do
        deployment = @deployment_manager.find_by_name(params[:name])

        options = {}
        options['force'] = true if params['force'] == 'true'
        options['keep_snapshots'] = true if params['keep_snapshots'] == 'true'
        task = @deployment_manager.delete_deployment(current_user, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      # Property management
      get '/:deployment/properties' do
        properties = @property_manager.get_properties(params[:deployment]).map do |property|
          { 'name' => property.name, 'value' => property.value }
        end
        json_encode(properties)
      end

      get '/:deployment/properties/:property' do
        property = @property_manager.get_property(params[:deployment], params[:property])
        json_encode('value' => property.value)
      end

      post '/:deployment/properties', :consumes => [:json] do
        payload = json_decode(request.body)
        @property_manager.create_property(params[:deployment], payload['name'], payload['value']  )
        status(204)
      end

      post '/:deployment/ssh', :consumes => [:json] do
        payload = json_decode(request.body)
        task = @instance_manager.ssh(current_user, payload)
        redirect "/tasks/#{task.id}"
      end

      put '/:deployment/properties/:property', :consumes => [:json] do
        payload = json_decode(request.body)
        @property_manager.update_property(params[:deployment], params[:property], payload['value'])
        status(204)
      end

      delete '/:deployment/properties/:property' do
        @property_manager.delete_property(params[:deployment], params[:property])
        status(204)
      end

      # Cloud check

      # Initiate deployment scan
      post '/:deployment/scans' do
        start_task { @problem_manager.perform_scan(current_user, params[:deployment]) }
      end

      # Get the list of problems for a particular deployment
      get '/:deployment/problems' do
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

      put '/:deployment/problems', :consumes => [:json] do
        payload = json_decode(request.body)
        start_task { @problem_manager.apply_resolutions(current_user, params[:deployment], payload['resolutions']) }
      end

      put '/:deployment/scan_and_fix', :consumes => :json do
        jobs_json = json_decode(request.body)['jobs']
        payload = convert_job_instance_hash(jobs_json)

        deployment = @deployment_manager.find_by_name(params[:deployment])
        if deployment_has_instance_to_resurrect?(deployment)
          start_task { @problem_manager.scan_and_fix(current_user, params[:deployment], payload) }
        end
      end

      post '/', :consumes => :yaml do
        options = {}
        options['recreate'] = true if params['recreate'] == 'true'
        options['skip_drain'] = params['skip_drain'] if params['skip_drain']
        if params['update_config']
          @logger.debug("Deploying with update config #{params['update_config']}")
          update_config = JSON.parse(params['update_config'])
          cloud_config = Api::CloudConfigManager.new.find_by_id(update_config['cloud_config_id'])
        else
          cloud_config =Api::CloudConfigManager.new.latest
        end

        task = @deployment_manager.create_deployment(current_user, request.body, cloud_config, options)
        redirect "/tasks/#{task.id}"
      end

      post '/:deployment/diff', :consumes => :yaml do
        deployment = Models::Deployment[name: params[:deployment]]
        if deployment
          before_manifest = Manifest.load_from_text(deployment.manifest, deployment.cloud_config)
          before_manifest.resolve_aliases
        else
          before_manifest = Manifest.load_from_text(nil, nil)
        end

        after_cloud_config = Bosh::Director::Api::CloudConfigManager.new.latest
        after_manifest = Manifest.load_from_text(
          request.body,
          after_cloud_config
        )
        after_manifest.resolve_aliases

        diff = before_manifest.diff(after_manifest)

        json_encode({
          'update_config' => {
            'cloud_config_id' => after_cloud_config ? after_cloud_config.id : nil,
          },
          'diff' => diff.map { |l| [l.to_s, l.status] }
        })
      end

      post '/:deployment_name/errands/:errand_name/runs' do
        deployment_name = params[:deployment_name]
        errand_name = params[:errand_name]
        keep_alive = json_decode(request.body)['keep-alive'] || FALSE

        task = JobQueue.new.enqueue(
          current_user,
          Jobs::RunErrand,
          "run errand #{errand_name} from deployment #{deployment_name}",
          [deployment_name, errand_name, keep_alive],
        )

        redirect "/tasks/#{task.id}"
      end

      get '/:deployment_name/errands', scope: :read do
        deployment_plan = load_deployment_plan

        errands = deployment_plan.jobs.select(&:can_run_as_errand?)

        errand_data = errands.map do |errand|
          { "name" => errand.name }
        end

        json_encode(errand_data)
      end

      private

      def load_deployment_plan
        deployment_model = @deployment_manager.find_by_name(params[:deployment_name])

        planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(Config.logger)
        planner_factory.create_from_model(deployment_model)
      end

      def convert_job_instance_hash(hash)
        hash.reduce([]) do |jobs, kv|
          job, indicies = kv
          jobs + indicies.map { |index| [job, index] }
        end
      end

      def deployment_has_instance_to_resurrect?(deployment)
        false if deployment.nil?
        filter = {
          deployment_id: deployment.id,
          resurrection_paused: false
        }
        instances = @instance_manager.filter_by(filter)
        instances.any?
      end

      def validate_instance_index_or_id(str)
        begin
          Integer(str)
        rescue ArgumentError
          if str !~ /^[A-Fa-f0-9]{8}-[A-Fa-f0-9-]{27}$/
            raise InstanceInvalidIndex, "Invalid instance index or id `#{str}'"
          end
        end
      end
    end
  end
end
