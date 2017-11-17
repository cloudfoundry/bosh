require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    module DeploymentsSecurity
      def route(verb, path, options = {}, &block)
        options[:scope] ||= :authorization
        options[:authorization] ||= :admin
        super(verb, path, options, &block)
      end

      def authorization(perm)
        return unless perm

        condition do
          subject = :director
          permission = perm

          if :diff == permission
            begin
              @deployment = Bosh::Director::Api::DeploymentLookup.new.by_name(params[:deployment])
              subject = @deployment
              permission = :admin
            rescue DeploymentNotFound
              permission = :create_deployment
            end
          else
            if params.has_key?('deployment')
              @deployment = Bosh::Director::Api::DeploymentLookup.new.by_name(params[:deployment])
              subject = @deployment
            end
          end

          @permission_authorizer.granted_or_raise(subject, permission, token_scopes)
        end
      end
    end

    class DeploymentsController < BaseController
      register DeploymentsSecurity
      include LegacyDeploymentHelper

      def initialize(config)
        super(config)
        @deployment_manager = Api::DeploymentManager.new
        @problem_manager = Api::ProblemManager.new
        @property_manager = Api::PropertyManager.new
        @instance_manager = Api::InstanceManager.new
        @deployments_repo = DeploymentPlan::DeploymentRepo.new
        @instance_ignore_manager = Api::InstanceIgnoreManager.new
      end

      get '/:deployment/jobs/:job/:index_or_id' do
        instance = @instance_manager.find_by_name(deployment, params[:job], params[:index_or_id])

        response = {
          deployment: deployment.name,
          job: instance.job,
          index: instance.index,
          id: instance.uuid,
          state: instance.state,
          disks: instance.persistent_disks.map { |d| d.disk_cid }
        }

        json_encode(response)
      end

      # PUT /deployments/foo/jobs/dea?new_name=dea_new or
      # PUT /deployments/foo/jobs/dea?state={started,stopped,detached,restart,recreate}&skip_drain=true&fix=true
      put '/:deployment/jobs/:job', :consumes => :yaml do
        options = {
          'job_states' => {
            params[:job] => {
              'state' => params['state']
            }
          }
        }

        options['skip_drain'] = params[:job] if params['skip_drain'] == 'true'
        options['canaries'] = params[:canaries] if !!params['canaries']
        options['max_in_flight'] = params[:max_in_flight] if !!params['max_in_flight']
        options['fix'] = true if params['fix'] == 'true'
        options['dry_run'] = true if params['dry_run'] == 'true'

        if (request.content_length.nil?  || request.content_length.to_i == 0) && (params['state'])
          manifest = deployment.manifest
          latest_cloud_configs = deployment.cloud_configs
          latest_runtime_configs = deployment.runtime_configs
          options['manifest_text'] = manifest
        else
          manifest_hash = validate_manifest_yml(request.body.read, nil)
          manifest =  YAML.dump(manifest_hash)
          latest_cloud_configs = Models::Config.latest_set('cloud')
          latest_runtime_configs = Models::Config.latest_set('runtime')
        end

        task = @deployment_manager.create_deployment(current_user, manifest, latest_cloud_configs, latest_runtime_configs, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      # PUT /deployments/foo/jobs/dea/2?state={started,stopped,detached,restart,recreate}&skip_drain=true&fix=true
      put '/:deployment/jobs/:job/:index_or_id', :consumes => :yaml do
        validate_instance_index_or_id(params[:index_or_id])

        instance = @instance_manager.find_by_name(deployment, params[:job], params[:index_or_id])
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
        options['fix'] = true if params['fix'] == 'true'
        options['dry_run'] = true if params['dry_run'] == 'true'

        if request.content_length.nil? || request.content_length.to_i == 0
          manifest = deployment.manifest
          latest_cloud_configs = deployment.cloud_configs
          latest_runtime_configs = deployment.runtime_configs
          options['manifest_text'] = manifest
        else
          manifest_hash = validate_manifest_yml(request.body.read, nil)
          manifest =  YAML.dump(manifest_hash)
          latest_cloud_configs = Models::Config.latest_set('cloud')
          latest_runtime_configs = Models::Config.latest_set('runtime')
        end

        task = @deployment_manager.create_deployment(current_user, manifest, latest_cloud_configs, latest_runtime_configs, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      # GET /deployments/foo/jobs/dea/2/logs
      get '/:deployment/jobs/:job/:index_or_id/logs' do
        job = params[:job] == "*" ? nil : params[:job]
        index_or_id = params[:index_or_id] == "*" ? nil : params[:index_or_id]
        options = {
          'type' => params[:type].to_s.strip,
          'filters' => params[:filters].to_s.strip.split(/[\s\,]+/)
        }

        task = @instance_manager.fetch_logs(current_user, deployment, job, index_or_id, options)
        redirect "/tasks/#{task.id}"
      end

      get '/:deployment/snapshots' do
        json_encode(@snapshot_manager.snapshots(deployment))
      end

      get '/:deployment/jobs/:job/:index/snapshots' do
        json_encode(@snapshot_manager.snapshots(deployment, params[:job], params[:index]))
      end

      post '/:deployment/snapshots' do
        # until we can tell the agent to flush and wait, all snapshots are considered dirty
        options = {clean: false}

        task = @snapshot_manager.create_deployment_snapshot_task(current_user, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      put '/:deployment/jobs/:job/:index_or_id/resurrection', consumes: :json do

        payload = json_decode(request.body.read)
        @resurrector_manager.set_pause_for_instance(deployment, params[:job], params[:index_or_id], payload['resurrection_paused'])
        status(200)
      end

      put '/:deployment/instance_groups/:instancegroup/:id/ignore', consumes: :json do
        payload = json_decode(request.body.read)
        @instance_ignore_manager.set_ignore_state_for_instance(deployment, params[:instancegroup], params[:id], payload['ignore'])
        status(200)
      end

      post '/:deployment/jobs/:job/:index_or_id/snapshots' do
        if params[:index_or_id].to_s =~ /^\d+$/
          instance = @instance_manager.find_by_name(deployment, params[:job], params[:index_or_id])
        else
          instance = @instance_manager.filter_by(deployment, uuid: params[:index_or_id]).first
        end
        # until we can tell the agent to flush and wait, all snapshots are considered dirty
        options = {clean: false}

        task = @snapshot_manager.create_snapshot_task(current_user, instance, options)
        redirect "/tasks/#{task.id}"
      end

      delete '/:deployment/snapshots' do
        task = @snapshot_manager.delete_deployment_snapshots_task(current_user, deployment)
        redirect "/tasks/#{task.id}"
      end

      delete '/:deployment/snapshots/:cid' do
        @snapshot_manager.find_by_cid(deployment, params[:cid])

        task = @snapshot_manager.delete_snapshots_task(current_user, [params[:cid]])
        redirect "/tasks/#{task.id}"
      end

      get '/', authorization: :list_deployments do
        latest_cloud_configs = Models::Config.latest_set('cloud').map(&:id).sort
        deployments = @deployment_manager.all_by_name_asc
          .select { |deployment| @permission_authorizer.is_granted?(deployment, :read, token_scopes) }
          .map do |deployment|
          cloud_config = if deployment.cloud_configs.empty?
                           'none'
                         elsif deployment.cloud_configs.map(&:id).sort == latest_cloud_configs
                           'latest'
                         else
                           'outdated'
                         end

          {
            'name' => deployment.name,
            'releases' => deployment.release_versions.sort { |a,b| [a.release.name, a.version] <=> [b.release.name, b.version] } .map do |rv|
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
            'cloud_config' => cloud_config,
            'teams' => deployment.teams.map { |t| t.name },
          }
        end

        json_encode(deployments)
      end

      get '/:deployment', authorization: :read do
        JSON.generate({'manifest' => deployment.manifest_text})
      end

      get '/:deployment/vms', authorization: :read do
        format = params[:format]
        if format == 'full'
          task = @instance_manager.fetch_instances_with_vm(current_user, deployment, format)
          redirect "/tasks/#{task.id}"
        else
          vms_instances_hash = @instance_manager.vms_by_instances_for_deployment(deployment)
          JSON.generate(create_vms_response(vms_instances_hash))
        end
      end

      get '/:deployment/instances', authorization: :read do
        format = params[:format]
        if format == 'full'
          task = @instance_manager.fetch_instances(current_user, deployment, format)
          redirect "/tasks/#{task.id}"
        else
          instances = @instance_manager.find_instances_by_deployment(deployment)
          JSON.generate(create_instances_response_with_vm_expected(instances))
        end
      end

      delete '/:deployment' do
        options = {}
        options['force'] = true if params['force'] == 'true'
        options['keep_snapshots'] = true if params['keep_snapshots'] == 'true'
        task = @deployment_manager.delete_deployment(current_user, deployment, options, @current_context_id)
        redirect "/tasks/#{task.id}"
      end

      post '/:deployment/ssh', :consumes => [:json] do
        payload = json_decode(request.body.read)
        task = @instance_manager.ssh(current_user, deployment, payload)
        redirect "/tasks/#{task.id}"
      end

      # Property management
      get '/:deployment/properties' do
        properties = @property_manager.get_properties(deployment).map do |property|
          {'name' => property.name, 'value' => property.value}
        end
        json_encode(properties)
      end

      get '/:deployment/properties/:property' do
        property = @property_manager.get_property(deployment, params[:property])
        json_encode('value' => property.value)
      end

      post '/:deployment/properties', :consumes => [:json] do
        payload = json_decode(request.body.read)
        @property_manager.create_property(deployment, payload['name'], payload['value'])
        status(204)
      end

      put '/:deployment/properties/:property', :consumes => [:json] do
        payload = json_decode(request.body.read)
        @property_manager.update_property(deployment, params[:property], payload['value'])
        status(204)
      end

      delete '/:deployment/properties/:property' do
        @property_manager.delete_property(deployment, params[:property])
        status(204)
      end

      get '/:deployment/variables' do
        result = deployment.variables.map { |variable|
          {
            'id' => variable.variable_id,
            'name' => variable.variable_name,
          }
        }.uniq

        json_encode(result)
      end

      # Cloud check

      # Initiate deployment scan
      post '/:deployment/scans' do
        start_task { @problem_manager.perform_scan(current_user, deployment) }
      end

      # Get the list of problems for a particular deployment
      get '/:deployment/problems' do
        problems = @problem_manager.get_problems(deployment).map do |problem|
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
        payload = json_decode(request.body.read)
        start_task { @problem_manager.apply_resolutions(current_user, deployment, payload['resolutions']) }
      end

      put '/:deployment/scan_and_fix', :consumes => :json do
        jobs_json = json_decode(request.body.read)['jobs']
        payload = convert_job_instance_hash(jobs_json)
        if deployment_has_instance_to_resurrect?(deployment)
          start_task { @problem_manager.scan_and_fix(current_user, deployment, payload) }
        end
      end

      post '/', authorization: :create_deployment, :consumes => :yaml do
        manifest_text = request.body.read
        manifest_hash = validate_manifest_yml(manifest_text, nil)

        unless manifest_hash['name']
          raise ValidationMissingField, "Deployment manifest must have a 'name' key"
        end

        options = {}
        options['dry_run'] = true if params['dry_run'] == 'true'
        options['recreate'] = true if params['recreate'] == 'true'
        options['skip_drain'] = params['skip_drain'] if params['skip_drain']
        options['fix'] = true if params['fix'] == 'true'
        options.merge!('scopes' => token_scopes)

        if params['context']
          @logger.debug("Deploying with context #{params['context']}")
          context = JSON.parse(params['context'])
          cloud_configs = Models::Config.find_by_ids(context['cloud_config_ids'])
          runtime_configs = Models::Config.find_by_ids(context['runtime_config_ids'])
        else
          cloud_configs = Models::Config.latest_set('cloud')
          runtime_configs = Models::Config.latest_set('runtime')
        end

        options['cloud_configs'] = cloud_configs
        options['runtime_configs'] = runtime_configs
        options['deploy'] = true

        deployment_name = manifest_hash['name']
        options['new'] = Models::Deployment[name: deployment_name].nil? ? true : false
        deployment_model = @deployments_repo.find_or_create_by_name(deployment_name, options)

        task = @deployment_manager.create_deployment(current_user, manifest_text, cloud_configs, runtime_configs, deployment_model, options, @current_context_id)

        redirect "/tasks/#{task.id}"
      end

      post '/:deployment/diff', authorization: :diff, :consumes => :yaml do
        begin
          manifest_text = request.body.read
          manifest_hash = validate_manifest_yml(manifest_text, nil)

          ignore_cc = ignore_cloud_config?(manifest_hash)

          if deployment
            before_manifest = Manifest.load_from_model(deployment, {:resolve_interpolation => false, :ignore_cloud_config => ignore_cc})
            before_manifest.resolve_aliases
          else
            before_manifest = Manifest.generate_empty_manifest
          end

          after_cloud_configs = ignore_cc ? nil : Bosh::Director::Models::Config.latest_set('cloud')
          after_runtime_configs = Bosh::Director::Models::Config.latest_set('runtime')

          after_manifest = Manifest.load_from_hash(manifest_hash, manifest_text, after_cloud_configs, after_runtime_configs, {:resolve_interpolation => false})
          after_manifest.resolve_aliases

          redact =  params['redact'] != 'false'

          result = {
            'context' => {
              'cloud_config_ids' => after_cloud_configs ? after_cloud_configs.map(&:id) : nil,
              'runtime_config_ids' => after_runtime_configs.map(&:id)
            }
          }

          diff = before_manifest.diff(after_manifest, redact)
          result['diff'] = diff.map { |l| [l.to_s, l.status] }
        rescue => error
          result = {
            'diff' => [],
            'error' => "Unable to diff manifest: #{error.inspect}\n#{error.backtrace.join("\n")}"
          }
          status(200)
        end

        json_encode(result)
      end

      post '/:deployment/errands/:errand_name/runs' do
        errand_name = params[:errand_name]
        parsed_request_body = json_decode(request.body.read)
        keep_alive = parsed_request_body['keep-alive'] || false
        when_changed = parsed_request_body['when-changed'] || false
        instances = parsed_request_body['instances'] || []

        task = JobQueue.new.enqueue(
          current_user,
          Jobs::RunErrand,
          "run errand #{errand_name} from deployment #{deployment.name}",
          [deployment.name, errand_name, keep_alive, when_changed, instances],
          deployment,
          @current_context_id
        )

        redirect "/tasks/#{task.id}"
      end

      get '/:deployment/errands', authorization: :read do
        deployment_plan = load_deployment_plan

        errands_instance_groups = deployment_plan.instance_groups.select(&:is_errand?)
        errands = errands_instance_groups.map(&:name)

        deployment_plan.instance_groups.each do |instance_group|
          instance_group.jobs.each do |job|
            errands << job.name if job.runs_as_errand?
          end
        end

        errands_hash = errands.uniq.map { |errand| {'name' => errand} }

        json_encode(errands_hash)
      end

      private

      attr_accessor :deployment

      def load_deployment_plan
        planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(Config.logger)
        planner_factory.create_from_model(deployment)
      end

      def convert_job_instance_hash(hash)
        hash.reduce([]) do |jobs, kv|
          job, indicies = kv
          jobs + indicies.map { |index| [job, index] }
        end
      end

      def deployment_has_instance_to_resurrect?(deployment)
        return false if deployment.nil?
        return false if @resurrector_manager.pause_for_all?
        instances = @instance_manager.filter_by(deployment, resurrection_paused: false, ignore: false)
        instances.any?
      end

      def validate_instance_index_or_id(str)
        begin
          Integer(str)
        rescue ArgumentError
          if str !~ /^[A-Fa-f0-9]{8}-[A-Fa-f0-9-]{27}$/
            raise InstanceInvalidIndex, "Invalid instance index or id '#{str}'"
          end
        end
      end

      def create_vms_response(vms_instances_hash)
        results = []
        vms_instances_hash.each_pair do |instance, vms|
          vms.each do |vm|
            results << create_vm_response(instance, vm)
          end
        end
        results
      end

      def create_instances_response_with_vm_expected(instances)
        instances.map do |instance|
          create_vm_response(instance, instance.active_vm).merge('expects_vm' => instance.expects_vm?)
        end
      end

      def create_vm_response(instance, vm)
        {
          'agent_id' => vm&.agent_id,
          'cid' => vm&.cid,
          'job' => instance.job,
          'index' => instance.index,
          'id' => instance.uuid,
          'az' => instance.availability_zone,
          'ips' => ips(instance),
          'vm_created_at' => vm&.created_at&.utc&.iso8601
        }
      end

      def ips(instance)
        result = instance.ip_addresses.map {|ip| NetAddr::CIDR.create(ip.address).ip }
        if result.empty? && instance.spec && instance.spec['networks']
          result = instance.spec['networks'].map {|_, network| network['ip']}
        end
        result
      end
    end
  end
end
