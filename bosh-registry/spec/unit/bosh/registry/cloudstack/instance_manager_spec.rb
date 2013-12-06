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
      "plugin" => "cloudstack",
      "cloudstack" => {
        "endpoint" => "http://127.0.0.1:5000/client",
        "api_key" => "foo",
        "secret_access_key" => "bar",
      }
    }
    Bosh::Registry.configure(config)
    Bosh::Registry.instance_manager
  end

  def create_instance(params)
    Bosh::Registry::Models::RegistryInstance.create(params)
  end

  def actual_ip_is(private_ip, floating_ip, instance_id)
    servers = double("servers")
    instance = double("instance")

    @compute.should_receive(:servers).and_return(servers)
    servers.should_receive(:find).and_return(instance)
    instance.should_receive(:nics).and_return([{'ipaddress' => private_ip}])
    if floating_ip
      floating_ips = {"publicipaddress" => [{"virtualmachineid" => instance_id, "ipaddress" => floating_ip}]}
    else
      floating_ips = {}
    end
    @compute.should_receive(:list_public_ip_addresses)
      .and_return({"listpublicipaddressesresponse" => floating_ips})
  end

  describe "reading settings" do
    it "returns settings after verifying IP address" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", nil, "foo")
      manager.read_settings("foo", "10.0.0.1").should == "bar"
    end

    it "returns settings after verifying floating IP address" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is(nil, "10.0.1.1", "foo")
      manager.read_settings("foo", "10.0.1.1").should == "bar"
    end

    it "raises an error if IP cannot be verified" do
      create_instance(:instance_id => "foo", :settings => "bar")
      actual_ip_is("10.0.0.1", "10.0.1.1", "foo")
      expect {
        manager.read_settings("foo", "10.0.2.1")
      }.to raise_error(Bosh::Registry::InstanceError,
                       "Instance IP mismatch, expected IP is `10.0.2.1', " \
                       "actual IP(s): `10.0.0.1, 10.0.1.1'")
    end

    it 'it should create a new fog connection if there is an Unauthorized error' do
      create_instance(:instance_id => 'foo', :settings => 'bar')
      @compute.should_receive(:servers).and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      actual_ip_is('10.0.0.1', nil, "foo")
      manager.read_settings('foo', '10.0.0.1').should == 'bar'
    end

    it 'it should raise a ConnectionError if there is a persistent Unauthorized error' do
      create_instance(:instance_id => 'foo', :settings => 'bar')
      @compute.should_receive(:servers).twice.and_raise(Excon::Errors::Unauthorized, 'Unauthorized')
      expect {
        manager.read_settings('foo', '10.0.0.1').should == 'bar'
      }.to raise_error(Bosh::Registry::ConnectionError, 'Unable to connect to CloudStack API: Unauthorized') 
    end
  end
end
