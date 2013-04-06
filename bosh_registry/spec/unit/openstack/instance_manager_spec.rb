# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::Registry::InstanceManager do

  before(:each) do
    @compute = double(Fog::Compute)
    Fog::Compute.stub(:new).and_return(@compute)
  end

  let(:manager) do
    config = valid_config
    config["cloud"] = {
      "plugin" => "openstack",
      "openstack" => {
        "auth_url" => "http://127.0.0.1:5000/v2.0/tokens",
        "username" => "foo",
        "api_key" => "bar",
        "tenant" => "foo",
        "region" => ""
      }
    }
    Bosh::Registry.configure(config)
    Bosh::Registry.instance_manager
  end

  def create_instance(params)
    Bosh::Registry::Models::RegistryInstance.create(params)
  end

  def actual_ip_is(private_ip, floating_ip)
    servers = mock("servers")
    instance = mock("instance")

    @compute.should_receive(:servers).and_return(servers)
    servers.should_receive(:find).and_return(instance)
    instance.should_receive(:private_ip_addresses).and_return([private_ip])
    instance.should_receive(:floating_ip_addresses).and_return([floating_ip])
  end

  describe "reading settings" do
    it "returns settings after verifying IP address" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", nil)
      manager.read_settings("foo", "10.0.0.1").should == "bar"
    end

    it "returns settings after verifying floating IP address" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is(nil, "10.0.1.1")
      manager.read_settings("foo", "10.0.1.1").should == "bar"
    end

    it "raises an error if IP cannot be verified" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", "10.0.1.1")
      expect {
        manager.read_settings("foo", "10.0.2.1")
      }.to raise_error(Bosh::Registry::InstanceError,
                       "Instance IP mismatch, expected IP is `10.0.2.1', " \
                       "actual IP(s): `10.0.0.1, 10.0.1.1'")
    end
  end

end
