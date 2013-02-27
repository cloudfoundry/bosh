# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.platform_name = "redhat"
Bosh::Agent::Config.platform

describe Bosh::Agent::Platform::Redhat::Network do

  describe "vsphere" do
    before(:each) do
      Bosh::Agent::Config.infrastructure_name = "vsphere"
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)
      Bosh::Agent::Config.settings = complete_settings

      @network_wrapper = Bosh::Agent::Platform::Redhat::Network.new
      @network_wrapper.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})

      @network_wrapper.should_receive(:restart_networking_service)
      @network_wrapper.should_receive(:gratuitous_arp)
    end

    it "should generate ubuntu network files" do
      Bosh::Agent::Util.stub!(:update_file) do |data, file|
        case file
        when '/etc/sysconfig/network-scripts/ifcfg-eth0'
          data.should == <<-EOF
DEVICE=eth0
BOOTPROTO=static
IPADDR=172.30.40.115
NETMASK=255.255.248.0
BROADCAST=172.30.47.255
GATEWAY=172.30.40.1
ONBOOT=yes
          EOF
        when '/etc/resolv.conf'
          data.should == <<-EOF
nameserver 172.30.22.153
nameserver 172.30.22.154
          EOF
        else
          raise "#{file} cannot be updated"
        end

        true
      end

      @network_wrapper.setup_networking
    end

    def complete_settings
      settings_json = %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"plugin":"simple","properties":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
      Yajl::Parser.new.parse(settings_json)
    end
  end

end
