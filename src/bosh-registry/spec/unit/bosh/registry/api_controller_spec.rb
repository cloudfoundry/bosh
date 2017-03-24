require "spec_helper"

describe Bosh::Registry::ApiController do

  before(:each) do
    Bosh::Registry.http_user = "admin"
    Bosh::Registry.http_password = "admin"

    @instance_manager = double("instance manager")
    Bosh::Registry.instance_manager = @instance_manager

    rack_mock = Rack::MockSession.new(Bosh::Registry::ApiController.new)
    @session = Rack::Test::Session.new(rack_mock)
  end

  def expect_json_response(response, status, body)
    expect(response.status).to eq(status)
    expect(Yajl::Parser.parse(response.body)).to eq(body)
  end

  it "returns settings for given instance (IP check)" do
    expect(@instance_manager).to receive(:read_settings).
      with("foo", "127.0.0.1").and_return("bar")

    @session.get("/instances/foo/settings")

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok", "settings" => "bar" })
  end

  it "returns settings (authorized user, no IP check)" do
    expect(@instance_manager).to receive(:read_settings).
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

    expect(@instance_manager).to receive(:update_settings).
      with("foo", "bar").and_return(true)

    @session.basic_authorize("admin", "admin")
    @session.put("/instances/foo/settings", {}, { :input => "bar" })

    expect_json_response(@session.last_response, 200,
                         { "status" => "ok" })
  end

  context "deletes settings" do
    it "deletes settings" do
      @session.delete("/instances/foo/settings")
      expect_json_response(@session.last_response, 401,
                           { "status" => "access_denied" })

      expect(@instance_manager).to receive(:delete_settings).
        with("foo").and_return(true)

      @session.basic_authorize("admin", "admin")
      @session.delete("/instances/foo/settings")

      expect_json_response(@session.last_response, 200,
                           { "status" => "ok" })
    end

    it "doesn't error when an instance isn't found" do
      expect(@instance_manager).to receive(:delete_settings).
        with("foo").and_raise Bosh::Registry::InstanceNotFound

      @session.basic_authorize("admin", "admin")
      @session.delete("/instances/foo/settings")

      expect_json_response(@session.last_response, 200,
                           { "status" => "ok" })
    end
  end

end