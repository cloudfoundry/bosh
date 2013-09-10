module Bosh::Director
  module Api
    class Controller < Sinatra::Base
      PUBLIC_URLS = %w(/info)

      include ApiHelper
      include Http
      include DnsHelper

      def initialize
        super
        @deployment_manager = DeploymentManager.new
        @backup_manager = BackupManager.new
        @instance_manager = InstanceManager.new
        @problem_manager = ProblemManager.new
        @property_manager = PropertyManager.new
        @resource_manager = ResourceManager.new
        @release_manager = ReleaseManager.new
        @snapshot_manager = SnapshotManager.new
        @stemcell_manager = StemcellManager.new
        @task_manager = TaskManager.new
        @user_manager = UserManager.new
        @vm_state_manager = VmStateManager.new
        @logger = Config.logger
      end

      mime_type :tgz, 'application/x-compressed'

      def self.consumes(*types)
        types = Set.new(types)
        types.map! { |t| mime_type(t) }

        condition do
          types.include?(request.content_type)
        end
      end

      def authenticate(user, password)
        if @user_manager.authenticate(user, password)
          @user = user
          true
        else
          false
        end
      end

      helpers ControllerHelpers

      before do
        auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect do |key|
          request.env.has_key?(key)
        end

        protected! if auth_provided || !PUBLIC_URLS.include?(request.path_info)
      end

      after { headers('Date' => Time.now.rfc822) } # As thin doesn't inject date

      configure do
        set(:show_exceptions, false)
        set(:raise_errors, false)
        set(:dump_errors, false)
      end

      error do
        exception = request.env['sinatra.error']
        if exception.kind_of?(DirectorError)
          @logger.debug('Request failed, ' +
                          "response code: #{exception.response_code}, " +
                          "error code: #{exception.error_code}, " +
                          "error message: #{exception.message}")
          status(exception.response_code)
          error_payload = {
            'code' => exception.error_code,
            'description' => exception.message
          }
          json_encode(error_payload)
        else
          msg = ["#{exception.class} - #{exception.message}:"]
          msg.concat(exception.backtrace)
          @logger.error(msg.join("\n"))
          status(500)
        end
      end

      post '/users', :consumes => [:json] do
        user = @user_manager.get_user_from_request(request)
        @user_manager.create_user(user)
        status(204)
        nil
      end

      put '/users/:username', :consumes => [:json] do
        user = @user_manager.get_user_from_request(request)
        if user.username != params[:username]
          raise UserImmutableUsername, 'The username is immutable'
        end
        @user_manager.update_user(user)
        status(204)
        nil
      end

      delete '/users/:username' do
        @user_manager.delete_user(params[:username])
        status(204)
        nil
      end

      post '/packages/matches', :consumes => :yaml do
        manifest = Psych.load(request.body)
        unless manifest.is_a?(Hash) && manifest['packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fp_list = []
        sha1_list = []

        manifest['packages'].each do |package|
          fp_list << package['fingerprint'] if package['fingerprint']
          sha1_list << package['sha1'] if package['sha1']
        end

        filter = {:fingerprint => fp_list, :sha1 => sha1_list}.sql_or

        result = Models::Package.where(filter).all.map { |package|
          [package.sha1, package.fingerprint]
        }.flatten.compact.uniq

        json_encode(result)
      end

      post '/releases', :consumes => :tgz do
        options = {}
        options['remote'] = false
        options['rebase'] = true if params['rebase'] == 'true'

        task = @release_manager.create_release(@user, request.body, options)
        redirect "/tasks/#{task.id}"
      end

      post '/releases', :consumes => :json do
        options = {}
        options['remote'] = true
        options['rebase'] = true if params['rebase'] == 'true'
        payload = json_decode(request.body)

        task = @release_manager.create_release(@user, payload['location'], options)
        redirect "/tasks/#{task.id}"
      end

      get '/releases' do
        releases = Models::Release.order_by(:name.asc).map do |release|
          release_versions = release.versions_dataset.order_by(:version.asc).map do |rv|
            Hash['version', rv.version.to_s,
                 'commit_hash', rv.commit_hash,
                 'uncommitted_changes', rv.uncommitted_changes,
                 'currently_deployed', !rv.deployments.empty?,
                 'job_names', rv.templates.map(&:name)]
          end

          Hash['name', release.name,
               'release_versions', release_versions]
        end

        json_encode(releases)
      end

      get '/releases/:name' do
        name = params[:name].to_s.strip
        release = @release_manager.find_by_name(name)

        result = { }

        result['packages'] = release.packages.map do |package|
          {
            'name' => package.name,
            'sha1' => package.sha1,
            'version' => package.version.to_s,
            'dependencies' => package.dependency_set.to_a
          }
        end

        result['jobs'] = release.templates.map do |template|
          {
            'name' => template.name,
            'sha1' => template.sha1,
            'version' => template.version.to_s,
            'packages' => template.package_names
          }
        end

        result['versions'] = release.versions.map do |rv|
          rv.version.to_s
        end

        content_type(:json)
        json_encode(result)
      end

      delete '/releases/:name' do
        release = @release_manager.find_by_name(params[:name])

        options = {}
        options['force'] = true if params['force'] == 'true'
        options['version'] = params['version']

        task = @release_manager.delete_release(@user, release, options)
        redirect "/tasks/#{task.id}"
      end

      post '/stemcells', :consumes => :tgz do
        task = @stemcell_manager.create_stemcell(@user, request.body, :remote => false)
        redirect "/tasks/#{task.id}"
      end

      post '/stemcells', :consumes => :json do
        payload = json_decode(request.body)
        task = @stemcell_manager.create_stemcell(@user, payload['location'], :remote => true)
        redirect "/tasks/#{task.id}"
      end

      get '/stemcells' do
        stemcells = Models::Stemcell.order_by(:name.asc).map do |stemcell|
          {
            'name' => stemcell.name,
            'version' => stemcell.version,
            'cid' => stemcell.cid
          }
        end
        json_encode(stemcells)
      end

      delete '/stemcells/:name/:version' do
        name, version = params[:name], params[:version]
        options = {}
        options['force'] = true if params['force'] == 'true'
        stemcell = @stemcell_manager.find_by_name_and_version(name, version)
        task = @stemcell_manager.delete_stemcell(@user, stemcell, options)
        redirect "/tasks/#{task.id}"
      end

      post '/deployments', :consumes => :yaml do
        options = {}
        options['recreate'] = true if params['recreate'] == 'true'

        task = @deployment_manager.create_deployment(@user, request.body, options)
        redirect "/tasks/#{task.id}"
      end

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

        instance = @instance_manager.find_by_name(params[:deployment], params[:job], params[:index])
        instance.resurrection_paused = payload['resurrection_paused']
        instance.save
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

      get '/tasks' do
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

      get '/tasks/:id' do
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
      get '/tasks/:id/output' do
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

      delete '/task/:id' do
        task_id = params[:id]
        task = @task_manager.find_task(task_id)

        if task.state != 'processing' && task.state != 'queued'
          status(400)
          body("Cannot cancel task #{task_id}: invalid state (#{task.state})")
        else
          task.state = :cancelling
          task.save
          status(204)
          body("Cancelling task #{task_id}")
        end
      end

      # JMS and MB: We don't know why this code exists. According to JP it shouldn't. We want to remove it.
      # To get comforable with that idea, we log something we can look for in production.
      #
      # GET /resources/deadbeef
      get '/resources/:id' do
        @logger.warn('Something is proxying a blob through the director. Find out why before we remove this method. ZAUGYZ')
        tmp_file = @resource_manager.get_resource_path(params[:id])
        send_disposable_file(tmp_file, :type => 'application/x-gzip')
      end

      post '/backups' do
        start_task { @backup_manager.create_backup(@user) }
      end

      get '/backups' do
        send_file @backup_manager.destination_path
      end

      get '/info' do
        status = {
          'name' => Config.name,
          'uuid' => Config.uuid,
          'version' => "#{VERSION} (#{Config.revision})",
          'user' => @user,
          'cpi' => Config.cloud_type,
          'features' => {
            'dns' => {
              'status' => Config.dns_enabled?,
              'extras' => { 'domain_name' => dns_domain_name }
            },
            'compiled_package_cache' => {
              'status' => Config.use_compiled_package_cache?,
              'extras' => { 'provider' => Config.compiled_package_cache_provider }
            },
            'snapshots' => {
              'status' => Config.enable_snapshots
            }
          }
        }
        content_type(:json)
        json_encode(status)
      end
    end
  end
end
