module Bosh; module Director; end; end

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

require "actionpool"
require "bcrypt"
require "blobstore_client"
require "eventmachine"
require "netaddr"
require "ohm"
require "resque"
require "sinatra"
require "uuidtools"
require "yajl"

require "director/thread_formatter"
require "director/deep_copy"
require "director/ext"
require "director/http_constants"
require "director/validation_helper"

require "director/client"
require "director/ip_util"
require "director/agent_client"
require "director/cloud"
require "director/cloud/vsphere"
require "director/cloud/dummy"
require "director/config"
require "director/configuration_hasher"
require "director/cycle_helper"
require "director/deployment_plan"
require "director/deployment_plan_compiler"
require "director/errors"
require "director/instance_updater"
require "director/job_updater"
require "director/lock"
require "director/package_compiler"
require "director/pubsub_redis"
require "director/release_manager"
require "director/resource_pool_updater"
require "director/thread_pool"
require "director/user_manager"
require "director/deployment_manager"
require "director/stemcell_manager"
require "director/jobs/base_job"
require "director/jobs/delete_deployment"
require "director/jobs/delete_release"
require "director/jobs/delete_stemcell"
require "director/jobs/update_deployment"
require "director/jobs/update_release"
require "director/jobs/update_stemcell"
require "director/models/compiled_package"
require "director/models/deployment"
require "director/models/instance"
require "director/models/package"
require "director/models/release"
require "director/models/release_version"
require "director/models/stemcell"
require "director/models/template"
require "director/models/task"
require "director/models/user"
require "director/models/vm"

module Bosh::Director

  class Controller < Sinatra::Base

    def initialize
      super
      @deployment_manager = DeploymentManager.new
      @release_manager    = ReleaseManager.new
      @stemcell_manager   = StemcellManager.new
      @user_manager       = UserManager.new
      @logger             = Config.logger
    end

    mime_type :tgz, "application/x-compressed"

    def self.consumes(*types)
      types = Set.new(types)
      types.map! { |t| mime_type(t) }

      condition do
        types.include?(request.content_type)
      end
    end

    configure do
      set(:show_exceptions, false)
      set(:raise_errors, false)
      set(:dump_errors, false)
    end

    before do
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)

      if @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials.length == 2 &&
              @user_manager.authenticate(*@auth.credentials)
        @user = @auth.username
        env["REMOTE_USER"] = @user # for logging
      else
        response["WWW-Authenticate"] = %(Basic realm="Testing HTTP Auth")
        error(UNAUTHORIZED, "Not authorized")
      end
    end

    error do
      exception = request.env['sinatra.error']
      if exception.kind_of?(DirectorError)
        @logger.debug("Request failed with response code: #{exception.response_code} error code: " +
                         "#{exception.error_code} error: #{exception.message}")
        status(exception.response_code)
        error_payload                = Hash.new
        error_payload['code']        = exception.error_code
        error_payload['description'] = exception.message
        Yajl::Encoder.encode(error_payload)
      else
        msg = ["#{exception.class} - #{exception.message}"]
        unless exception.kind_of?(ServerError) && exception.omit_stack
          msg[0] = msg[0] + ":"
          msg.concat(exception.backtrace)
        end
        @logger.warn(msg.join("\n"))
        status(500)
      end
    end

    post "/users", :consumes => [:json] do
      user = @user_manager.get_user_from_request(request)
      @user_manager.create_user(user)
    end

    put "/users/:username", :consumes => [:json] do
      user = @user_manager.get_user_from_request(request)
      raise UserImmutableUsername unless user.username == params[:username]
      @user_manager.update_user(user)
    end

    delete "/users/:username" do
      @user_manager.delete_user(params[:username])
    end

    post "/releases", :consumes => :tgz do
      task = @release_manager.create_release(request.body)
      redirect "/tasks/#{task.id}"
    end

    get "/releases" do
      releases = Models::Release.all.sort_by(:name, :order => "ASC ALPHA").map do |release|
        {
          "name"     => release.name,
          "versions" => release.versions.sort_by(:version).map { |rv| rv.version.to_s }
        }
      end

      Yajl::Encoder.encode(releases)
    end

    # TODO: delete a release

    post "/deployments", :consumes => :yaml do
      task = @deployment_manager.create_deployment(request.body)
      redirect "/tasks/#{task.id}"
    end

    get "/deployments" do
      deployments = Models::Deployment.all.sort_by(:name, :order => "ASC ALPHA").map do |deployment|
        {
          "name" => deployment.name
        }
      end

      Yajl::Encoder.encode(deployments)
    end

    delete "/deployments/:name" do
      deployment = Models::Deployment.find(:name => params[:name]).first
      raise DeploymentNotFound.new(params[:name]) if deployment.nil?
      task = @deployment_manager.delete_deployment(deployment)
      redirect "/tasks/#{task.id}"
    end

    # TODO: get information about an existing deployment
    # TODO: stop, start, restart jobs/instances

    post "/stemcells", :consumes => :tgz do
      task = @stemcell_manager.create_stemcell(request.body)
      redirect "/tasks/#{task.id}"
    end

    get "/stemcells" do
      stemcells = Models::Stemcell.all.sort_by(:name, :order => "ASC ALPHA").map do |stemcell|
        {
          "name"    => stemcell.name,
          "version" => stemcell.version,
          "cid"     => stemcell.cid
        }
      end
      Yajl::Encoder.encode(stemcells)
    end

    delete "/stemcells/:name/:version" do
      stemcell = Models::Stemcell.find(:name => params[:name], :version => params[:version]).first
      raise StemcellNotFound.new(params[:name], params[:version]) if stemcell.nil?
      task = @stemcell_manager.delete_stemcell(stemcell)
      redirect "/tasks/#{task.id}"
    end

    get "/running_tasks" do
      tasks = Models::Task.find(:state => "processing").sort_by(:timestamp).map do |task|
        { "id" => task.id, "state" => task.state, "timestamp" => task.timestamp.to_i, "result" => task.result }
      end
      Yajl::Encoder.encode(tasks)
    end

    get "/recent_tasks/:count" do
      count = params[:count].to_i
      count = 1 if count < 1
      tasks = Models::Task.all.sort_by(:timestamp, :order => "DESC", :limit => count).map do |task|
        { "id" => task.id, "state" => task.state, "timestamp" => task.timestamp.to_i, "result" => task.result }
      end
      Yajl::Encoder.encode(tasks)
    end

    get "/tasks/:id" do
      task = Models::Task[params[:id]]
      raise TaskNotFound.new(params[:id]) if task.nil?

      # TODO: fix output to be in JSON format exporting state, timestamp, and result.
      content_type("text/plain")
      task.state
    end

    get "/tasks/:id/output" do
      task = Models::Task[params[:id]]
      raise TaskNotFound.new(params[:id]) if task.nil?
      if task.output && File.file?(task.output)
        send_file(task.output, :type => "text/plain")
      else
        status(NO_CONTENT)
      end
    end

    get "/status" do
      # TODO: add version to director
      Yajl::Encoder.encode("status" => "Bosh Director (logged in as #{@user})")
    end

  end

end

