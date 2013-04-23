# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Director
  end
end

require "digest/sha1"
require "erb"
require "fileutils"
require "forwardable"
require "logger"
require "monitor"
require "optparse"
require "ostruct"
require "pp"
require "thread"
require "tmpdir"
require "yaml"
require "time"
require "zlib"

require "common/exec"
require "common/properties"

require "bcrypt"
require "blobstore_client"
require "eventmachine"
require "netaddr"
require "resque"
require "sequel"
require "sinatra/base"
require "securerandom"
require "yajl"
require "nats/client"
require "securerandom"

require "common/thread_formatter"
require "encryption/encryption_handler"
require "director/api"
require "director/deep_copy"
require "director/dns_helper"
require "director/errors"
require "director/ext"
require "director/ip_util"
require "director/lock_helper"
require "director/metadata_helper"
require "director/validation_helper"

require "director/version"
require "director/config"
require "director/event_log"
require "director/task_result_file"
require "director/version_calc"
require "director/blob_util"

require "director/client"
require "director/agent_client"
require "cloud"
require "director/compile_task"
require "director/configuration_hasher"
require "director/cycle_helper"
require "director/encryption_helper"
require "director/vm_creator"
require "director/vm_data"
require "director/vm_reuser"
require "director/deployment_plan"
require "director/deployment_plan_compiler"
require "director/duration"
require "director/instance_deleter"
require "director/instance_updater"
require "director/job_runner"
require "director/job_updater"
require "director/lock"
require "director/nats_rpc"
require "director/network_reservation"
require "director/package_compiler"
require "director/problem_scanner"
require "director/problem_resolver"
require "director/resource_pool_updater"
require "director/sequel"
require "common/thread_pool"

require "director/cloudcheck_helper"
require "director/problem_handlers/base"
require "director/problem_handlers/invalid_problem"
require "director/problem_handlers/inactive_disk"
require "director/problem_handlers/out_of_sync_vm"
require "director/problem_handlers/unresponsive_agent"
require "director/problem_handlers/unbound_instance_vm"
require "director/problem_handlers/mount_info_mismatch"
require "director/problem_handlers/missing_vm"

require "director/jobs/base_job"
require "director/jobs/delete_deployment"
require "director/jobs/delete_release"
require "director/jobs/delete_stemcell"
require "director/jobs/update_deployment"
require "director/jobs/update_release"
require "director/jobs/update_stemcell"
require "director/jobs/fetch_logs"
require "director/jobs/vm_state"
require "director/jobs/cloud_check/scan"
require "director/jobs/cloud_check/scan_and_fix"
require "director/jobs/cloud_check/apply_resolutions"
require "director/jobs/ssh"

require "director/models/helpers/model_helper"

module Bosh::Director
  autoload :Models, "director/models"

  class ThreadPool < Bosh::ThreadPool
    def initialize(options)
      options[:logger] ||= Config.logger
      super(options)
    end
  end

  class ApiController < Sinatra::Base
    PUBLIC_URLS = ["/info"]

    include Api::ApiHelper
    include Api::Http
    include DnsHelper

    def initialize
      super
      @deployment_manager = Api::DeploymentManager.new
      @instance_manager = Api::InstanceManager.new
      @problem_manager = Api::ProblemManager.new
      @property_manager = Api::PropertyManager.new
      @resource_manager = Api::ResourceManager.new
      @release_manager = Api::ReleaseManager.new
      @stemcell_manager = Api::StemcellManager.new
      @task_manager = Api::TaskManager.new
      @user_manager = Api::UserManager.new
      @vm_state_manager = Api::VmStateManager.new
      @logger = Config.logger
    end

    mime_type :tgz, "application/x-compressed"

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

    helpers do
      def task_timeout?(task)
        # Some of the old task entries might not have the checkpoint_time
        unless task.checkpoint_time
          task.checkpoint_time = Time.now
          task.save
        end

        # If no checkpoint update in 3 cycles --> timeout
        (task.state == "processing" || task.state == "cancelling") &&
          (Time.now - task.checkpoint_time > Config.task_checkpoint_interval * 3)
      end

      def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="BOSH Director")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials && authenticate(*@auth.credentials)
      end
    end

    before do
      auth_provided = %w(HTTP_AUTHORIZATION X-HTTP_AUTHORIZATION X_HTTP_AUTHORIZATION).detect do |key|
        request.env.has_key?(key)
      end

      protected! if auth_provided || !PUBLIC_URLS.include?(request.path_info)
    end

    after { headers("Date" => Time.now.rfc822) } # As thin doesn't inject date

    configure do
      set(:show_exceptions, false)
      set(:raise_errors, false)
      set(:dump_errors, false)
    end

    error do
      exception = request.env["sinatra.error"]
      if exception.kind_of?(DirectorError)
        @logger.debug("Request failed, " +
                        "response code: #{exception.response_code}, " +
                        "error code: #{exception.error_code}, " +
                        "error message: #{exception.message}")
        status(exception.response_code)
        error_payload = {
          "code" => exception.error_code,
          "description" => exception.message
        }
        json_encode(error_payload)
      else
        msg = ["#{exception.class} - #{exception.message}:"]
        msg.concat(exception.backtrace)
        @logger.error(msg.join("\n"))
        status(500)
      end
    end

    post "/users", :consumes => [:json] do
      user = @user_manager.get_user_from_request(request)
      @user_manager.create_user(user)
      status(204)
      nil
    end

    put "/users/:username", :consumes => [:json] do
      user = @user_manager.get_user_from_request(request)
      if user.username != params[:username]
        raise UserImmutableUsername, "The username is immutable"
      end
      @user_manager.update_user(user)
      status(204)
      nil
    end

    delete "/users/:username" do
      @user_manager.delete_user(params[:username])
      status(204)
      nil
    end

    post "/releases", :consumes => :tgz do
      options = {}
      options["rebase"] = true if params["rebase"] == "true"

      task = @release_manager.create_release(@user, request.body, options)
      redirect "/tasks/#{task.id}"
    end

    get "/releases" do
      releases = Models::Release.order_by(:name.asc).map do |release|
        release_versions = release.versions_dataset.order_by(:version.asc).map do |rv|
          Hash["version", rv.version.to_s,
               "commit_hash", rv.commit_hash,
               "uncommitted_changes", rv.uncommitted_changes,
               "currently_deployed", !rv.deployments.empty?]
        end

        Hash["name", release.name,
             "release_versions", release_versions]
      end

      json_encode(releases)
    end

    delete "/releases/:name" do
      release = @release_manager.find_by_name(params[:name])

      options = {}
      options["force"] = true if params["force"] == "true"
      options["version"] = params["version"]

      task = @release_manager.delete_release(@user, release, options)
      redirect "/tasks/#{task.id}"
    end

    post "/deployments", :consumes => :yaml do
      options = {}
      options["recreate"] = true if params["recreate"] == "true"

      task = @deployment_manager.create_deployment(@user, request.body, options)
      redirect "/tasks/#{task.id}"
    end

    get "/deployments/:deployment/jobs/:job/:index" do
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
    put "/deployments/:deployment/jobs/:job", :consumes => :yaml do
      if params["state"]
        options = {
          "job_states" => {
            params[:job] => {
              "state" => params["state"]
            }
          }
        }
      else
        unless params["new_name"]
          raise DirectorError, "Missing operation on job `#{params[:job]}'"
        end
        options = {
          "job_rename" => {
            "old_name" => params[:job],
            "new_name" => params["new_name"]
          }
        }
        options["job_rename"]["force"] = true if params["force"] == "true"
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
    get "/deployments/:deployment/jobs/:job/:index/logs" do
      deployment = params[:deployment]
      job = params[:job]
      index = params[:index]

      options = {
        "type" => params[:type].to_s.strip,
        "filters" => params[:filters].to_s.strip.split(/[\s\,]+/)
      }

      task = @instance_manager.fetch_logs(@user, deployment, job, index, options)
      redirect "/tasks/#{task.id}"
    end

    get "/deployments" do
      deployments = Models::Deployment.order_by(:name.asc).map { |deployment|
        name = deployment.name

        releases = deployment.release_versions.map { |rv|
          Hash["name", rv.release.name, "version", rv.version.to_s]
        }

        stemcells = deployment.stemcells.map { |sc|
          Hash["name", sc.name, "version", sc.version]
        }

        Hash["name", name, "releases", releases, "stemcells", stemcells]
      }

      json_encode(deployments)
    end

    get "/deployments/:name" do
      deployment = @deployment_manager.find_by_name(params[:name])
      @deployment_manager.deployment_to_json(deployment)
    end

    get "/deployments/:name/vms" do
      deployment = @deployment_manager.find_by_name(params[:name])

      format = params[:format]
      if format == "full"
        task = @vm_state_manager.fetch_vm_state(@user, deployment, format)
        redirect "/tasks/#{task.id}"
      else
        @deployment_manager.deployment_vms_to_json(deployment)
      end
    end

    delete "/deployments/:name" do
      deployment = @deployment_manager.find_by_name(params[:name])

      options = {}
      options["force"] = true if params["force"] == "true"
      task = @deployment_manager.delete_deployment(@task, deployment, options)
      redirect "/tasks/#{task.id}"
    end

    # TODO: stop, start, restart jobs/instances

    post "/stemcells", :consumes => :tgz do
      task = @stemcell_manager.create_stemcell(@task, request.body)
      redirect "/tasks/#{task.id}"
    end

    get "/stemcells" do
      stemcells = Models::Stemcell.order_by(:name.asc).map do |stemcell|
        {
          "name"    => stemcell.name,
          "version" => stemcell.version,
          "cid"     => stemcell.cid
        }
      end
      json_encode(stemcells)
    end

    delete "/stemcells/:name/:version" do
      name, version = params[:name], params[:version]
      options = {}
      options["force"] = true if params["force"] == "true"
      stemcell = @stemcell_manager.find_by_name_and_version(name, version)
      task = @stemcell_manager.delete_stemcell(@user, stemcell, options)
      redirect "/tasks/#{task.id}"
    end

    get "/releases/:name" do
      name = params[:name].to_s.strip
      release = @release_manager.find_by_name(name)

      result = { }

      result["packages"] = release.packages.map do |package|
        {
          "name"    => package.name,
          "sha1"    => package.sha1,
          "version" => package.version.to_s,
          "dependencies" => package.dependency_set.to_a
        }
      end

      result["jobs"] = release.templates.map do |template|
        {
          "name"     => template.name,
          "sha1"     => template.sha1,
          "version"  => template.version.to_s,
          "packages" => template.package_names
        }
      end

      result["versions"] = release.versions.map do |rv|
        rv.version.to_s
      end

      content_type(:json)
      json_encode(result)
    end

    post "/packages/matches", :consumes => :yaml do
      manifest = Psych.load(request.body)
      unless manifest.is_a?(Hash) && manifest["packages"].is_a?(Array)
        raise BadManifest, "Manifest doesn't have a usable packages section"
      end

      fp_list = []
      sha1_list = []

      manifest["packages"].each do |package|
        fp_list << package["fingerprint"] if package["fingerprint"]
        sha1_list << package["sha1"] if package["sha1"]
      end

      filter = {:fingerprint => fp_list, :sha1 => sha1_list}.sql_or

      result = Models::Package.where(filter).all.map { |package|
        [package.sha1, package.fingerprint]
      }.flatten.compact.uniq

      json_encode(result)
    end

    get "/tasks" do
      dataset = Models::Task.dataset
      limit = params["limit"]
      if limit
        limit = limit.to_i
        limit = 1 if limit < 1
        dataset = dataset.limit(limit)
      end

      states = params["state"].to_s.split(",")

      if states.size > 0
        dataset = dataset.filter(:state => states)
      end

      verbose = params["verbose"] || "1"
      if verbose == "1"
        dataset = dataset.filter(:type => [
            "update_deployment", "delete_deployment", "update_release",
            "delete_release", "update_stemcell", "delete_stemcell"])
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

    get "/tasks/:id" do
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
    get "/tasks/:id/output" do
      log_type = params[:type] || "debug"
      task = @task_manager.find_task(params[:id])

      if task.output.nil?
        halt(204)
      end

      log_file = @task_manager.log_file(task, log_type)

      if File.file?(log_file)
        send_file(log_file, :type => "text/plain")
      else
        status(204)
      end
    end

    delete "/task/:id" do
      task_id = params[:id]
      task = @task_manager.find_task(task_id)

      if task.state != "processing" && task.state != "queued"
        status(400)
        body("Cannot cancel task #{task_id}: invalid state (#{task.state})")
      else
        task.state = :cancelling
        task.save
        status(204)
        body("Cancelling task #{task_id}")
      end
    end

    # GET /resources/deadbeef
    get "/resources/:id" do
      tmp_file = @resource_manager.get_resource_path(params[:id])
      send_disposable_file(tmp_file, :type => "application/x-gzip")
    end

    # Property management
    get "/deployments/:deployment/properties" do
      properties = @property_manager.get_properties(params[:deployment]).map do |property|
        { "name" => property.name, "value" => property.value }
      end
      json_encode(properties)
    end

    get "/deployments/:deployment/properties/:property" do
      property = @property_manager.get_property(params[:deployment], params[:property])
      json_encode("value" => property.value)
    end

    post "/deployments/:deployment/properties", :consumes => [:json] do
      payload = json_decode(request.body)
      @property_manager.create_property(params[:deployment], payload["name"], payload["value"])
      status(204)
    end

    post "/deployments/:deployment/ssh", :consumes => [:json] do
      payload = json_decode(request.body)
      task = @instance_manager.ssh(@user, payload)
      redirect "/tasks/#{task.id}"
    end

    put "/deployments/:deployment/properties/:property", :consumes => [:json] do
      payload = json_decode(request.body)
      @property_manager.update_property(params[:deployment], params[:property], payload["value"])
      status(204)
    end

    delete "/deployments/:deployment/properties/:property" do
      @property_manager.delete_property(params[:deployment], params[:property])
      status(204)
    end

    # Cloud check

    # Initiate deployment scan
    post "/deployments/:deployment/scans" do
      start_task { @problem_manager.perform_scan(@user, params[:deployment]) }
    end

    # Get the list of problems for a particular deployment
    get "/deployments/:deployment/problems" do
      problems = @problem_manager.get_problems(params[:deployment]).map do |problem|
        {
          "id" => problem.id,
          "type" => problem.type,
          "data" => problem.data,
          "description" => problem.description,
          "resolutions" => problem.resolutions
        }
      end

      json_encode(problems)
    end

    # Try to resolve a set of problems
    put "/deployments/:deployment/problems", :consumes => [:json] do
      payload = json_decode(request.body)
      start_task { @problem_manager.apply_resolutions(@user, params[:deployment], payload["resolutions"]) }
    end

    put '/deployments/:deployment/scan_and_fix', :consumes => :json do
      payload = json_decode(request.body)
      # payload: {j1 => [i1, i2, ...], j2 => [i1, i2, ...]}
      start_task { @problem_manager.scan_and_fix(@user, params[:deployment], payload["jobs"]) }
    end

    get "/info" do
      status = {
        "name"     => Config.name,
        "uuid"     => Config.uuid,
        "version"  => "#{VERSION} (#{Config.revision})",
        "user"     => @user,
        "cpi"      => Config.cloud_type,
        "features" => {
          "dns" => {
            "status" => Config.dns_enabled?,
            "extras" => { "domain_name" => dns_domain_name }
          },
          "compiled_package_cache" => {
            "status" => Config.use_compiled_package_cache?
          }
        }
      }
      content_type(:json)
      json_encode(status)
    end
  end
end
