# TODO: convert to a gem instead?
$:.unshift(::File.expand_path("../../../blobstore_client/lib", __FILE__))
require "blobstore_client"

module Bosh
  module Director
  end
end

require "digest/sha1"
require "erb"
require "fileutils"
require "logger"
require "optparse"
require "ostruct"
require "pp"
require "tmpdir"
require "yaml"

require "actionpool"
require "eventmachine"
require "netaddr"
require "ohm"
require "resque"
require "sinatra"
require "uuidtools"
require "yajl"

require "director/ext"
require "director/deep_copy"
require "director/validation_helper"
require "director/client"
require "director/ip_util"
require "director/agent_client"
require "director/cloud"
require "director/cloud/vsphere"
require "director/config"
require "director/configuration_hasher"
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
require "director/user_manager"
require "director/deployment_manager"
require "director/stemcell_manager"
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
      @release_manager = ReleaseManager.new
      @stemcell_manager = StemcellManager.new
      @user_manager = UserManager.new
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
        error(401, "Not authorized")
      end
    end

    error UserNotFound do
      error(404, "User not found")
    end

    error UserInvalid do
      error = env["sinatra.error"]
      #TODO: provide real error codes
      error(400, error.errors.pretty_inspect)
    end

    error TaskNotFound do
      error(404, "Task not found")
    end

    error do
      boom = env["sinatra.error"]
      msg = ["#{boom.class} - #{boom.message}:", *boom.backtrace].join("\n ")
      @env["rack.errors"].puts(msg)

      # print error/backtrace for test environment only
      if test?
        puts msg
      end
    end

    post "/users", :consumes => [:json] do
      user = @user_manager.get_user_from_request(request)
      @user_manager.create_user(user)
    end

    put "/users/:username", :consumes => [:json] do
      user = @user_manager.get_user_from_request(request)
      raise UserInvalid.new([[:username, :immutable]]) unless user.username == params[:username]
      @user_manager.update_user(user)
    end

    delete "/users/:username" do
      @user_manager.delete_user(params[:username])
    end

    post "/releases", :consumes => :tgz do
      task = @release_manager.create_release(request.body)
      redirect "/tasks/#{task.id}"
    end

    # TODO: get information about an existing release
    # TODO: delete a release

    post "/deployments", :consumes => :yaml do
      task = @deployment_manager.create_deployment(request.body)
      redirect "/tasks/#{task.id}"
    end

    # TODO: get information about an existing deployment
    # TODO: delete deployment?
    # TODO: stop, start, restart jobs/instances

    post "/stemcells", :consumes => :tgz do
      task = @stemcell_manager.create_stemcell(request.body)
      redirect "/tasks/#{task.id}"
    end

    # TODO: get information about an existing stemcell
    # TODO: delete stemcell

    get "/tasks/:id" do
      task = Models::Task[params[:id]]
      raise TaskNotFound if task.nil?

      # TODO: fix output to be in JSON format exporting state, timestamp, and result.
      content_type("text/plain")
      task.state
    end

    # TODO: create an endpoint for task output
  end
end
