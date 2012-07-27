# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Infrastructure.new("openstack").infrastructure

describe Bosh::Agent::Infrastructure::Openstack::Registry do

  before(:each) do
    @settings = { 'status' => "ok", 'settings' => settings_json }
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

  def settings_json
    %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"plugin":"simple","properties":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
  end

end