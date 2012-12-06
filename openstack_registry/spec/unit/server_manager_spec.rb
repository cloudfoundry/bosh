# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenstackRegistry::ServerManager do

  before(:each) do
    @compute = double(Fog::Compute)
    Fog::Compute.stub(:new).and_return(@compute)
    openstack = mock("openstack")
    Bosh::OpenstackRegistry.openstack = openstack
  end

  let(:manager) do
    Bosh::OpenstackRegistry::ServerManager.new
  end

  def create_server(params)
    Bosh::OpenstackRegistry::Models::OpenstackServer.create(params)
  end

  def actual_ip_is(private_ip, floating_ip = nil)
    servers = mock("servers")
    server = mock("server", :addresses => {
        "private" => [{"version" => 4, "addr" => private_ip}],
        "public" => [floating_ip]
    })

    @compute.should_receive(:servers).and_return(servers)
    servers.should_receive(:get).with("foo").and_return(server)
  end

  describe "reading settings" do
    it "returns settings after verifying IP address" do
      create_server(:server_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1")
      manager.read_settings("foo", "10.0.0.1").should == "bar"
    end

    it "returns settings after verifying floating IP address" do
      create_server(:server_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", "10.0.1.1")
      manager.read_settings("foo", "10.0.1.1").should == "bar"
    end

    it "raises an error if IP cannot be verified" do
      create_server(:server_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", "10.0.1.1")
      expect {
        manager.read_settings("foo", "10.0.2.1")
      }.to raise_error(Bosh::OpenstackRegistry::ServerError,
                       "Server IP mismatch, expected IP is `10.0.2.1', " \
                       "actual IP(s): `10.0.0.1, 10.0.1.1'")
    end

    it "doesn't check remote IP if it's not provided" do
      create_server(:server_id => "foo", :settings => "bar")
      manager.read_settings("foo").should == "bar"
    end

    it "raises an error if server not found" do
      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::OpenstackRegistry::ServerNotFound,
                       "Can't find server `foo'")
    end
  end

  describe "updating settings" do
    it "updates settings (new server)" do
      manager.update_settings("foo", "baz")
      manager.read_settings("foo").should == "baz"
    end

    it "updates settings (existing server)" do
      create_server(:server_id => "foo", :settings => "bar")
      manager.read_settings("foo").should == "bar"
      manager.update_settings("foo", "baz")
      manager.read_settings("foo").should == "baz"
    end
  end

  describe "deleting settings" do
    it "deletes settings" do
      manager.update_settings("foo", "baz")
      manager.delete_settings("foo")

      expect {
        manager.read_settings("foo")
      }.to raise_error(Bosh::OpenstackRegistry::ServerNotFound,
                       "Can't find server `foo'")
    end

    it "raises an error if server not found" do
      expect {
        manager.delete_settings("foo")
      }.to raise_error(Bosh::OpenstackRegistry::ServerNotFound,
                       "Can't find server `foo'")
    end
  end

end
