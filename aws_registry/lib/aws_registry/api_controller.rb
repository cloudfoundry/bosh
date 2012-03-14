# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsRegistry

  class ApiController < Sinatra::Base

    not_found do
      json(:status => "not_found")
    end

    error do
      exception = request.env["sinatra.error"]
      @logger.error(exception)
      status(500)
      json(:status => "error")
    end

    get "/instances/:instance_id/settings" do
      ip_check = authorized? ? nil : request.ip
      settings = @instance_manager.read_settings(params[:instance_id], ip_check)
      json(:status => "ok", :settings => settings)
    end

    put "/instances/:instance_id/settings" do
      protected!
      @instance_manager.update_settings(params[:instance_id], request.body.read)
      json(:status => "ok")
    end

    delete "/instances/:instance_id/settings" do
      protected!
      @instance_manager.delete_settings(params[:instance_id])
      json(:status => "ok")
    end

    def initialize
      super
      @logger = Bosh::AwsRegistry.logger

      @users = Set.new
      @users << [Bosh::AwsRegistry.http_user, Bosh::AwsRegistry.http_password]
      @instance_manager = InstanceManager.new
    end

    def protected!
      unless authorized?
        headers("WWW-Authenticate" => 'Basic realm="EC2 Registry"')
        halt(401, json("status" => "access_denied"))
      end
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? &&
        @auth.basic? &&
        @auth.credentials &&
        @users.include?(@auth.credentials)
    end

    def json(payload)
      Yajl::Encoder.encode(payload)
    end

  end

end
