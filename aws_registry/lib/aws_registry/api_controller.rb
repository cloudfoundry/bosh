# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsRegistry

  # EC2 agents use private EC2 IP address for
  # authentication, as it guaranteed to be unique
  # during VM lifecycle. This simplifies credentials
  # management, as we only need one set of credentials
  # for CPI itself to modify agent settings but no
  # per-agent credentials.
  class ApiController < Sinatra::Base

    def initialize
      super
      @logger = Bosh::AwsRegistry.logger
      @users = Set.new
      @users << [Bosh::AwsRegistry.http_user, Bosh::AwsRegistry.http_password]
    end

    def protected!
      unless authorized?
        response["WWW-Authenticate"] = %(Basic realm="EC2 Registry")
        throw :halt, [401, "Not authorized\n"]
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

    def get_settings(ip)
      agent_settings = Models::AgentSettings[:ip_address => ip]

      if agent_settings.nil?
        status(404)
        json(:status => "not_found")
      else
        json(:status => "ok", :settings => agent_settings.settings)
      end
    end

    configure do
      set(:show_exceptions, false)
      set(:raise_errors, false)
      set(:dump_errors, false)
    end

    error do
      exception = request.env["sinatra.error"]
      @logger.error(exception)
      status(500)
      json(:status => "error")
    end

    get "/settings", :provides => "json" do
      get_settings(request.ip)
    end

    before "/agents/*" do
      protected!
    end

    get "/agents/:ip_address/settings", :provides => "json" do
      get_settings(params[:ip_address])
    end

    put "/agents/:ip_address/settings", :provides => "json" do
      ip_address = params[:ip_address]

      agent_settings = Models::AgentSettings[:ip_address => ip_address]

      if agent_settings.nil?
        agent_settings = Models::AgentSettings.new(:ip_address => ip_address)
      end

      agent_settings.settings = request.body.read
      agent_settings.save
      json(:status => "ok")
    end

    delete "/agents/:ip_address/settings", :provides => "json" do
      ip_address = params[:ip_address]

      agent_settings = Models::AgentSettings[:ip_address => ip_address]

      if agent_settings.nil?
        status(404)
        json(:status => "not_found")
      else
        agent_settings.destroy
        json(:status => "ok")
      end
    end

  end

end
