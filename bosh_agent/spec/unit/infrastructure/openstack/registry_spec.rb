# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Infrastructure.new("openstack").infrastructure

describe Bosh::Agent::Infrastructure::Openstack::Registry do

  before(:each) do
    @settings = { 'status' => "ok", 'settings' => settings_json }
  end

  it "should raise exception when settings are invalid" do
    Bosh::Agent::Infrastructure::Openstack::Registry.stub(:current_instance_id).and_return("os_instance")
    Bosh::Agent::Infrastructure::Openstack::Registry.stub(:get_json_from_url).and_return({})
    Bosh::Agent::Infrastructure::Openstack::Registry.stub(:get_registry_endpoint).and_return("blah")
    expect {
      settings = Bosh::Agent::Infrastructure::Openstack::Registry.get_settings
    }.to raise_error Bosh::Agent::LoadSettingsError
  end

  it 'should get settings' do
    Bosh::Agent::Infrastructure::Openstack::Registry.stub(:current_server_id).and_return("i-server")
    Bosh::Agent::Infrastructure::Openstack::Registry.stub(:get_json_from_url).and_return(@settings)
    Bosh::Agent::Infrastructure::Openstack::Registry.stub(:get_registry_endpoint).and_return("blah")
    settings = Bosh::Agent::Infrastructure::Openstack::Registry.get_settings
    settings.should == Yajl::Parser.new.parse(settings_json)
  end

  it 'should get registry endpoint' do
    endpoint = {"registry" => {"endpoint" => "blah"}}
    Bosh::Agent::Infrastructure::Openstack::Registry.stub(:get_json_from_url).and_return(endpoint)
    Bosh::Agent::Infrastructure::Openstack::Registry.get_registry_endpoint.should == "blah"
  end

  it 'should get current_server_id' do
    class TestHTTPResponse
      def status
        200
      end
      def body
        "{\"registry\": {\"endpoint\": \"blah\"}, \"server\": {\"name\": \"server-id\"}}"
      end
    end

    client = HTTPClient.new
    client.stub(:get).and_return(TestHTTPResponse.new)
    HTTPClient.stub(:new).and_return(client)
    server_id = Bosh::Agent::Infrastructure::Openstack::Registry.current_server_id
    server_id.should == "server-id"
  end

  context "dns server" do
    it 'should replace registry hostname with ip' do
      hostname = "0.registry.default.openstack.bosh"
      nameservers = ["1.2.3.4"]
      Bosh::Agent::Infrastructure::Openstack::Registry
        .should_receive(:bosh_lookup)
        .with(hostname, nameservers)
        .and_return("4.3.2.1")

      data = user_data("http://#{hostname}:25777", nameservers)
      endpoint = Bosh::Agent::Infrastructure::Openstack::Registry
                   .lookup_registry(data)
      endpoint.should == "http://4.3.2.1:25777"
    end

    it 'should allow registry endpoint with ip' do
      hostname = "4.3.2.1"
      nameservers = ["1.2.3.4"]

      data = user_data("http://#{hostname}:25777", nameservers)
      endpoint = Bosh::Agent::Infrastructure::Openstack::Registry
                   .lookup_registry(data)
      endpoint.should == "http://4.3.2.1:25777"
    end

    it "should raise an error when it can't lookup the name" do
      hostname = "foo.com"
      nameservers = ["1.1.1.1", "2.2.2.2"]
      Bosh::Agent::Infrastructure::Openstack::Registry
        .should_receive(:bosh_lookup)
        .with(hostname, nameservers)
        .and_raise(Resolv::ResolvError)

      data = user_data("http://#{hostname}:25777", nameservers)
      expect {
        Bosh::Agent::Infrastructure::Openstack::Registry.lookup_registry(data)
      }.to raise_error Bosh::Agent::LoadSettingsError,
                      /Cannot lookup foo.com using 1.1.1.1, 2.2.2.2/
    end
  end

  def user_data(endpoint, nameservers)
    {
      "registry" => {
        "endpoint" => endpoint
      },
      "dns" => {
        "nameserver" => nameservers
      }
   }
  end

  def settings_json
    %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"provider":"simple","options":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
  end

end