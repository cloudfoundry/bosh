# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::OpenstackRegistry

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

    get "/servers/:server_id/settings" do
      ip_check = authorized? ? nil : request.ip
      settings = @server_manager.read_settings(params[:server_id])
      json(:status => "ok", :settings => settings)
    end

    put "/servers/:server_id/settings" do
      protected!
      @server_manager.update_settings(params[:server_id], request.body.read)
      json(:status => "ok")
    end

    delete "/servers/:server_id/settings" do
      protected!
      @server_manager.delete_settings(params[:server_id])
      json(:status => "ok")
    end

    def initialize
      super
      @logger = Bosh::OpenstackRegistry.logger

      @users = Set.new
      @users << [Bosh::OpenstackRegistry.http_user, Bosh::OpenstackRegistry.http_password]
      @server_manager = ServerManager.new
    end

    def protected!
      unless authorized?
        headers("WWW-Authenticate" => 'Basic realm="OpenStack Registry"')
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
