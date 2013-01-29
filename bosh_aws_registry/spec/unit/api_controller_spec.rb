# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsRegistry::ApiController do

  before(:each) do
    Bosh::AwsRegistry.http_user = "admin"
    Bosh::AwsRegistry.http_password = "admin"

    @instance_manager = mock("instance manager")
    Bosh::AwsRegistry::InstanceManager.stub!(:new).and_return(@instance_manager)

    rack_mock = Rack::MockSession.new(Bosh::AwsRegistry::ApiController.new)
    @session = Rack::Test::Session.new(rack_mock)
  end

  def expect_json_response(response, status, body)
    response.status.should == status
    Yajl::Parser.parse(response.body).should == body
  end

  it "returns settings for given EC2 instance (IP check)" do
    @instance_manager.should_receive(:read_settings).
      with("foo", "127.0.0.1").and_return("bar")

    @session.get("/instances/foo/settings")

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok", "settings" => "bar" })
  end

  it "returns settings (authorized user, no IP check)" do
    @instance_manager.should_receive(:read_settings).
      with("foo", nil).and_return("bar")

    @session.basic_authorize("admin", "admin")
    @session.get("/instances/foo/settings")

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok", "settings" => "bar" })
  end

  it "updates settings" do
    @session.put("/instances/foo/settings", {}, { :input => "bar" })
    expect_json_response(@session.last_response, 401,
                         { "status" => "access_denied" })

    @instance_manager.should_receive(:update_settings).
      with("foo", "bar").and_return(true)

    @session.basic_authorize("admin", "admin")
    @session.put("/instances/foo/settings", {}, { :input => "bar" })

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok" })
  end

  it "deletes settings" do
    @session.delete("/instances/foo/settings")
    expect_json_response(@session.last_response, 401,
                         { "status" => "access_denied" })

    @instance_manager.should_receive(:delete_settings).
      with("foo").and_return(true)

    @session.basic_authorize("admin", "admin")
    @session.delete("/instances/foo/settings")

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok" })
  end

end
