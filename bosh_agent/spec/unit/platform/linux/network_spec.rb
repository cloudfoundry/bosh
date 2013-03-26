# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/linux/network'

describe Bosh::Agent::Platform::Linux::Network do

  let(:complete_settings) {
    Yajl::Parser.new.parse %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},
                              "disks":{"ephemeral":1,"persistent":{"250":2},"system":0},
                              "mbus":"nats://user:pass@11.0.0.11:4222","networks":
                              {"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70",
                              "ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1",
                              "dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},
                              "blobstore":{"provider":"simple","options":{"password":"Ag3Nt","user":"agent",
                              "endpoint":"http://172.30.40.11:25250"}},
                              "ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],
                              "agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
  }

  let(:partial_settings) {
    Yajl::Parser.new.parse %q[{"networks":{"default":{"dns":["1.2.3.4","5.6.7.8"],"default":["gateway","dns"]}}]
  }

  before(:each) do
    Bosh::Agent::Config.infrastructure_name = "vsphere"
    Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)
    Bosh::Agent::Config.settings = complete_settings

    @network_wrapper = Bosh::Agent::Platform::Linux::Network.new(nil)
    # We just want to avoid this to accidentally be invoked on dev systems
    Bosh::Agent::Util.stub(:update_file)
    @network_wrapper.stub(:gratuitous_arp)
    @network_wrapper.stub(:write_network_interfaces)
  end

  context "vSphere" do
    it "should fail when network information is incomplete" do
      Bosh::Agent::Config.settings = partial_settings
      @network_wrapper.should_receive(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
      lambda { @network_wrapper.setup_networking }.should raise_error(Bosh::Agent::FatalError)
    end

    it "should delegate updating the network interface files to the platform implementation" do
      @network_wrapper.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})

      @network_wrapper.should_receive(:write_network_interfaces).and_call_original
      expect { @network_wrapper.setup_networking }.to raise_error(Bosh::Agent::UnimplementedMethod)
    end

    it "should update the resolv.conf file" do
      @network_wrapper.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})

      Bosh::Agent::Util.should_receive(:update_file) do |result, file_path|
        result.should == "nameserver 172.30.22.153\nnameserver 172.30.22.154\n"
        file_path.should == '/etc/resolv.conf'
      end
      @network_wrapper.setup_networking
    end
  end

  context "AWS" do
    it "should delegate DHCP configuration to platform implementation" do
      Bosh::Agent::Config.infrastructure_name = "aws"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(partial_settings)
      Bosh::Agent::Config.settings = partial_settings

      @network_wrapper.should_receive(:write_dhcp_conf).and_call_original
      expect { @network_wrapper.setup_networking }.to raise_error(Bosh::Agent::UnimplementedMethod)
    end
  end

  context "OpenStack" do
    let(:partial_settings) do
      json = %q[{"networks":{"default":{"dns":["1.2.3.4"],"default":["gateway","dns"]}}]
      Yajl::Parser.new.parse(json)
    end

    it "should delegate DHCP configuration to platform implementation" do
      Bosh::Agent::Config.infrastructure_name = "openstack"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(partial_settings)
      Bosh::Agent::Config.settings = partial_settings

      @network_wrapper.should_receive(:write_dhcp_conf).and_call_original
      expect { @network_wrapper.setup_networking }.to raise_error(Bosh::Agent::UnimplementedMethod)
    end
  end
end
