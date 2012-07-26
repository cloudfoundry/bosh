# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenstackRegistry::ApiController do

  before(:each) do
    Bosh::OpenstackRegistry.http_user = "admin"
    Bosh::OpenstackRegistry.http_password = "admin"

    @server_manager = mock("server manager")
    Bosh::OpenstackRegistry::ServerManager.stub!(:new).and_return(@server_manager)

    rack_mock = Rack::MockSession.new(Bosh::OpenstackRegistry::ApiController.new)
    @session = Rack::Test::Session.new(rack_mock)
  end

  def expect_json_response(response, status, body)
    response.status.should == status
    Yajl::Parser.parse(response.body).should == body
  end

  it "returns settings for given OpenStack server (IP check)" do
    @server_manager.should_receive(:read_settings).
      with("foo").and_return("bar")

    @session.get("/servers/foo/settings")

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok", "settings" => "bar" })
  end

  it "returns settings (authorized user, no IP check)" do
    @server_manager.should_receive(:read_settings).
      with("foo").and_return("bar")

    @session.basic_authorize("admin", "admin")
    @session.get("/servers/foo/settings")

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok", "settings" => "bar" })
  end

  it "updates settings" do
    @session.put("/servers/foo/settings", {}, { :input => "bar" })
    expect_json_response(@session.last_response, 401,
                         { "status" => "access_denied" })

    @server_manager.should_receive(:update_settings).
      with("foo", "bar").and_return(true)

    @session.basic_authorize("admin", "admin")
    @session.put("/servers/foo/settings", {}, { :input => "bar" })

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok" })
  end

  it "deletes settings" do
    @session.delete("/servers/foo/settings")
    expect_json_response(@session.last_response, 401,
                         { "status" => "access_denied" })

    @server_manager.should_receive(:delete_settings).
      with("foo").and_return(true)

    @session.basic_authorize("admin", "admin")
    @session.delete("/servers/foo/settings")

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok" })
  end

end
