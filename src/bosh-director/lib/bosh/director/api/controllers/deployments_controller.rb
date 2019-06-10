require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class DeploymentsController < BaseController
      register Bosh::Director::Api::Extensions::DeploymentsSecurity

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
          disks: instance.persistent_disks.map(&:disk_cid),
        }

        json_encode(response)
      end

      # PUT /deployments/foo/jobs/dea?new_name=dea_new or
      # PUT /deployments/foo/jobs/dea?state={started,stopped,detached,restart,recreate}&skip_drain=true&fix=true
      put '/:deployment/jobs/:job', consumes: :yaml do
        options = {
          'job_states' => {
            params[:job] => {
              'state' => params['state'],
            },
          },
        }

        options['skip_drain'] = params[:job] if params['skip_drain'] == 'true'
        options['canaries'] = params[:canaries] if !!params['canaries']
        options['max_in_flight'] = params[:max_in_flight] if !!params['max_in_flight']
        options['fix'] = true if params['fix'] == 'true'
        options['dry_run'] = true if params['dry_run'] == 'true'

        if (request.content_length.nil? || request.content_length.to_i == 0) && params['state']
          manifest = deployment.manifest
          latest_cloud_configs = deployment.cloud_configs
          latest_runtime_configs = deployment.runtime_configs
          options['manifest_text'] = manifest
        else
          manifest_hash = validate_manifest_yml(request.body.read, nil)
          manifest = YAML.dump(manifest_hash)
          teams = deployment.teams
          latest_cloud_configs = Models::Config.latest_set_for_teams('cloud', *teams)
          latest_runtime_configs = Models::Config.latest_set_for_teams('runtime', *teams)
        end

        task = @deployment_manager.create_deployment(
          current_user,
          manifest,
          latest_cloud_configs,
          latest_runtime_configs,
          deployment,
          options,
          @current_context_id,
        )
        redirect "/tasks/#{task.id}"
      end

      # PUT /deployments/foo/jobs/dea/2?state={started,stopped,detached,restart,recreate}&skip_drain=true&fix=true
      put '/:deployment/jobs/:job/:index_or_id', consumes: :yaml do
        validate_instance_index_or_id(params[:index_or_id])

        instance = @instance_manager.find_by_name(deployment, params[:job], params[:index_or_id])
        index = instance.index

        options = {
          'job_states' => {
            params[:job] => {
              'instance_states' => {
                index => params['state'],
              },
            },
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
          manifest = YAML.dump(manifest_hash)
          teams = deployment.teams
          latest_cloud_configs = Models::Config.latest_set_for_teams('cloud', *teams)
          latest_runtime_configs = Models::Config.latest_set_for_teams('runtime', *teams)
        end

        task = @deployment_manager.create_deployment(
          current_user,
          manifest,
          latest_cloud_configs,
          latest_runtime_configs,
          deployment,
          options,
          @current_context_id,
        )
        redirect "/tasks/#{task.id}"
      end

      post '/:deployment/jobs/:job/:index_or_id/actions/:action' do
        validate_instance_index_or_id(params[:index_or_id])

        instance = @instance_manager.find_by_name(deployment, params[:job], params[:index_or_id])
        options = {
          skip_drain: params['skip_drain'] == 'true',
          hard: params['hard'] == 'true',
        }

        if params[:action] == 'stop'
          task = JobQueue.new.enqueue(
            current_user,
            Jobs::StopInstance,
            'stop instance',
            [deployment.name, instance.id, options],
            deployment,
            @current_context_id,
          )
          redirect "/tasks/#{task.id}"
        end
      end

      # GET /deployments/foo/jobs/dea/2/logs
      get '/:deployment/jobs/:job/:index_or_id/logs' do
        job = params[:job] == '*' ? nil : params[:job]
        index_or_id = params[:index_or_id] == '*' ? nil : params[:index_or_id]
        options = {
          'type' => params[:type].to_s.strip,
          'filters' => params[:filters].to_s.strip.split(/[\s\,]+/),
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
        options = { clean: false }

        task = @snapshot_manager.create_deployment_snapshot_task(current_user, deployment, options)
        redirect "/tasks/#{task.id}"
      end

      put '/:deployment/jobs/:job/:index_or_id/resurrection' do
        gone_status = 410
        status(gone_status)

        'This endpoint has been removed. Please use '\
          'https://bosh.io/docs/resurrector/#enable-with-resurrection-config to configure resurrection for the '\
          'deployment or instance group. If you need to prevent a single instance from being resurrected, '\
          'consider using https://bosh.io/docs/cli-v2/#ignore.'
      end

      put '/:deployment/instance_groups/:instancegroup/:id/ignore', consumes: :json do
        payload = json_decode(request.body.read)
        @instance_ignore_manager.set_ignore_state_for_instance(deployment, params[:instancegroup], params[:id], payload['ignore'])
        status(200)
      end

      post '/:deployment/jobs/:job/:index_or_id/snapshots' do
        instance = if params[:index_or_id].to_s.match?(/^\d+$/)
                     @instance_manager.find_by_name(deployment, params[:job], params[:index_or_id])
                   else
                     @instance_manager.filter_by(deployment, uuid: params[:index_or_id]).first
                   end
        # until we can tell the agent to flush and wait, all snapshots are considered dirty
        options = { clean: false }

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

      def used_cloud_config_state(deployment)
        latest_cloud_configs = Models::Config.latest_set_for_teams('cloud', *deployment.teams).map(&:id).sort
        if deployment.cloud_configs.empty?
          'none'
        elsif deployment.cloud_configs.map(&:id).sort == latest_cloud_configs
          'latest'
        else
          'outdated'
        end
      end

      def stemcells_state(deployment)
        deployment.stemcells.map { |sc| { 'name' => sc.name, 'version' => sc.version } }
      end

      def releases_state(deployment)
        sorted_releases = deployment.release_versions.sort do |a, b|
          [a.release.name, a.version] <=> [b.release.name, b.version]
        end
        sorted_releases.map { |rv| { 'name' => rv.release.name, 'version' => rv.version.to_s } }
      end

      get '/', authorization: :list_deployments do
        excludes = {
          exclude_configs: params[:exclude_configs] == 'true',
          exclude_releases: params[:exclude_releases] == 'true',
          exclude_stemcells: params[:exclude_stemcells] == 'true',
        }
        all_deployments = @deployment_manager.all_by_name_asc_without(excludes)

        my_deployments = all_deployments.select do |deployment|
          @permission_authorizer.is_granted?(deployment, :read, token_scopes)
        end
        deployments = my_deployments.map do |deployment|
          response = {
            'name' => deployment.name,
            'teams' => deployment.teams.map(&:name),
          }
          response['cloud_config'] = used_cloud_config_state(deployment) unless excludes[:exclude_configs]
          response['stemcells'] = stemcells_state(deployment) unless excludes[:exclude_stemcells]
          response['releases'] = releases_state(deployment) unless excludes[:exclude_releases]
          response
        end

        json_encode(deployments)
      end

      get '/:deployment', authorization: :read do
        JSON.generate('manifest' => deployment.manifest_text)
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

      get '/:deployment/certificate_expiry', authorization: :read do
        deployment_certificate_provider = Api::DeploymentCertificateProvider.new
        JSON.generate(deployment_certificate_provider.list_certificates_with_expiry(deployment))
      end

      delete '/:deployment' do
        options = {}
        options['force'] = true if params['force'] == 'true'
        options['keep_snapshots'] = true if params['keep_snapshots'] == 'true'
        task = @deployment_manager.delete_deployment(current_user, deployment, options, @current_context_id)
        redirect "/tasks/#{task.id}"
      end

      post '/:deployment/ssh', consumes: [:json] do
        payload = json_decode(request.body.read)
        task = @instance_manager.ssh(current_user, deployment, payload)
        redirect "/tasks/#{task.id}"
      end

      # Property management
      get '/:deployment/properties' do
        properties = @property_manager.get_properties(deployment).map do |property|
          { 'name' => property.name, 'value' => property.value }
        end
        json_encode(properties)
      end

      get '/:deployment/properties/:property' do
        property = @property_manager.get_property(deployment, params[:property])
        json_encode('value' => property.value)
      end

      post '/:deployment/properties', consumes: [:json] do
        payload = json_decode(request.body.read)
        @property_manager.create_property(deployment, payload['name'], payload['value'])
        status(204)
      end

      put '/:deployment/properties/:property', consumes: [:json] do
        payload = json_decode(request.body.read)
        @property_manager.update_property(deployment, params[:property], payload['value'])
        status(204)
      end

      delete '/:deployment/properties/:property' do
        @property_manager.delete_property(deployment, params[:property])
        status(204)
      end

      get '/:deployment/variables' do
        result = deployment.variables.map do |variable|
          {
            'id' => variable.variable_id,
            'name' => variable.variable_name,
          }
        end.uniq

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
            'resolutions' => problem.resolutions,
          }
        end

        json_encode(problems)
      end

      put '/:deployment/problems', consumes: [:json] do
        payload = json_decode(request.body.read)
        start_task { @problem_manager.apply_resolutions(current_user, deployment, payload['resolutions']) }
      end

      put '/:deployment/scan_and_fix', consumes: :json do
        jobs_json = json_decode(request.body.read)['jobs']
        payload = convert_job_instance_hash(jobs_json)
        if deployment_has_instance_to_resurrect?(deployment)
          start_task { @problem_manager.scan_and_fix(current_user, deployment, payload) }
        end
      end

      post '/', authorization: :create_deployment, consumes: :yaml do
        manifest_text = request.body.read.force_encoding('utf-8')
        manifest_hash = validate_manifest_yml(manifest_text, nil)

        raise ValidationMissingField, "Deployment manifest must have a 'name' key" unless manifest_hash['name']

        deployment_name = manifest_hash['name']

        options = {}
        options['dry_run'] = true if params['dry_run'] == 'true'
        options['recreate'] = true if params['recreate'] == 'true'
        options['recreate_persistent_disks'] = true if params['recreate_persistent_disks'] == 'true'
        options['skip_drain'] = params['skip_drain'] if params['skip_drain']
        options['fix'] = true if params['fix'] == 'true'
        options['scopes'] = token_scopes

        # since authorizer does not look at manifest payload for deployment name
        @deployment = Models::Deployment[name: deployment_name]
        if @deployment
          teams = @deployment.teams
        else
          teams = Bosh::Director::Models::Team.transform_admin_team_scope_to_teams(token_scopes)
        end

        if params['context']
          @logger.debug("Deploying with context #{params['context']}")
          context = JSON.parse(params['context'])

          begin
            cloud_configs = Models::Config.find_by_ids_for_teams(context['cloud_config_ids'], *teams)
            runtime_configs = Models::Config.find_by_ids_for_teams(context['runtime_config_ids'], *teams)
          rescue Sequel::NoMatchingRow
            raise DeploymentInvalidConfigReference, 'Context includes invalid config ID'
          end
        else
          cloud_configs = Models::Config.latest_set_for_teams('cloud', *teams)
          runtime_configs = Models::Config.latest_set_for_teams('runtime', *teams)
        end

        options['cloud_configs'] = cloud_configs
        options['runtime_configs'] = runtime_configs
        options['deploy'] = true

        options['new'] = @deployment.nil? ? true : false
        deployment_model = @deployments_repo.find_or_create_by_name(deployment_name, options)

        task = @deployment_manager.create_deployment(
          current_user,
          manifest_text,
          cloud_configs,
          runtime_configs,
          deployment_model,
          options,
          @current_context_id,
        )

        redirect "/tasks/#{task.id}"
      end

      post '/:deployment/diff', authorization: :diff, consumes: :yaml do
        begin
          manifest_text = request.body.read
          manifest_hash = validate_manifest_yml(manifest_text, nil)

          if deployment
            before_manifest = Manifest.load_from_model(deployment, resolve_interpolation: false)
            before_manifest.resolve_aliases
            teams = deployment.teams
          else
            before_manifest = Manifest.generate_empty_manifest
            teams = Bosh::Director::Models::Team.transform_admin_team_scope_to_teams(token_scopes)
          end

          after_cloud_configs = Bosh::Director::Models::Config.latest_set_for_teams('cloud', *teams)
          after_runtime_configs = Bosh::Director::Models::Config.latest_set_for_teams('runtime', *teams)

          after_manifest = Manifest.load_from_hash(
            manifest_hash,
            manifest_text,
            after_cloud_configs,
            after_runtime_configs,
            resolve_interpolation:
            false,
          )
          after_manifest.resolve_aliases

          redact = params['redact'] != 'false'

          result = {
            'context' => {
              'cloud_config_ids' => after_cloud_configs ? after_cloud_configs.map(&:id) : nil,
              'runtime_config_ids' => after_runtime_configs.map(&:id),
            },
          }

          diff = before_manifest.diff(after_manifest, redact, teams)
          result['diff'] = diff.map { |l| [l.to_s, l.status] }
        rescue StandardError => error
          result = {
            'diff' => [],
            'error' => "Unable to diff manifest: #{error.inspect}\n#{error.backtrace.join("\n")}",
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
          @current_context_id,
        )

        redirect "/tasks/#{task.id}"
      end

      get '/:deployment/errands', authorization: :read do
        deployment_plan = load_deployment_plan

        errands_instance_groups = deployment_plan.instance_groups.select(&:errand?)
        errands = errands_instance_groups.map(&:name)

        deployment_plan.instance_groups.each do |instance_group|
          instance_group.jobs.each do |job|
            errands << job.name if job.runs_as_errand?
          end
        end

        errands_hash = errands.uniq.map { |errand| { 'name' => errand } }

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

        instances = @instance_manager.filter_by(deployment, ignore: false)
        instances.any?
      end

      def validate_instance_index_or_id(str)
        Integer(str)
      rescue ArgumentError
        raise InstanceInvalidIndex, "Invalid instance index or id '#{str}'" if str !~ /^[A-Fa-f0-9]{8}-[A-Fa-f0-9-]{27}$/
      end

      def create_vms_response(vms_instances_hash)
        results = []
        vms_instances_hash.each_pair do |instance, vms|
          vms.each do |vm|
            results << create_vm_response(instance, vm).merge('active' => vm.active)
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
          'ips' => ips(vm),
          'vm_created_at' => vm&.created_at&.utc&.iso8601,
        }
      end

      def ips(vm)
        return [] if vm.nil?

        # For manual and vip networks
        result = vm.ip_addresses.map { |ip| NetAddr::CIDR.create(ip.address).ip }

        # For dynamic networks
        result = vm.network_spec.map { |_, network| network['ip'] } if result.empty? && !vm.network_spec.empty?
        result
      end
    end
  end
end
