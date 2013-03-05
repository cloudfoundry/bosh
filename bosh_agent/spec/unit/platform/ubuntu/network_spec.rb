# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Bosh::Agent::Platform::Ubuntu::Network do

  describe "common" do
    let(:network) { Bosh::Agent::Platform::Ubuntu::Network.new }

    it "should update hostname" do
      hostname = "example.com"
      Bosh::Exec.should_receive(:sh).with("hostname #{hostname}")
      Bosh::Agent::Util.should_receive(:update_file).twice do |data, file|
        case file
        when "/etc/hostname"
          data.should == hostname
        when "/etc/hosts"
          data.should =~ /127\.0\.0\.1 localhost #{hostname}/
        else
          raise "#{file} cannot be updated"
        end
      end

      network.update_hostname(hostname)
    end
  end

  describe "vsphere" do
    before(:each) do
      Bosh::Agent::Config.infrastructure_name = "vsphere"
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)
      Bosh::Agent::Config.settings = complete_settings

      @network_wrapper = Bosh::Agent::Platform::Ubuntu::Network.new
      # We just want to avoid this to accidentally be invoked on dev systems
      @network_wrapper.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
      @network_wrapper.should_receive(:restart_networking_service)
      @network_wrapper.should_receive(:gratuitous_arp)
    end

    # FIXME: pending network config refactoring
    #it "should fail when network information is incomplete" do
    #  @network_wrapper.load_settings
    #  @network_wrapper.stub!(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
    #  lambda { @processor.setup_networking }.should raise_error(Bosh::Agent::FatalError, /contains invalid characters/)
    #end

    it "should generate ubuntu network files" do
      Bosh::Agent::Util.stub(:update_file) do |data, file|
        case file
        when '/etc/network/interfaces'
          data.should == "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet static\n    address 172.30.40.115\n    network 172.30.40.0\n    netmask 255.255.248.0\n    broadcast 172.30.47.255\n    gateway 172.30.40.1\n\n"
        when '/etc/resolv.conf'
          data.should == "nameserver 172.30.22.153\nnameserver 172.30.22.154\n"
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

  describe "aws" do
    def partial_settings
      json = %q[{"networks":{"default":{"dns":["1.2.3.4","5.6.7.8"],"default":["gateway","dns"]}}]
      Yajl::Parser.new.parse(json)
    end

    it "should configure dhcp with dns server prepended" do
      Bosh::Agent::Config.infrastructure_name = "aws"
      settings = partial_settings
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(settings)
      Bosh::Agent::Config.settings = settings

      @network_wrapper = Bosh::Agent::Platform::Ubuntu::Network.new
      Bosh::Agent::Util.should_receive(:update_file) do |contents, file|
        contents.should match /^prepend domain-name-servers 5\.6\.7\.8;\nprepend domain-name-servers 1\.2\.3\.4;$/
        file.should == "/etc/dhcp3/dhclient.conf"
        true # fake a change
      end
      @network_wrapper.should_receive(:restart_dhclient)
      @network_wrapper.setup_networking
    end
  end

  describe "OpenStack" do
    def partial_settings
      json = %q[{"networks":{"default":{"dns":["1.2.3.4"],"default":["gateway","dns"]}}]
      Yajl::Parser.new.parse(json)
    end

    it "should configure dhcp with dns server prepended" do
      Bosh::Agent::Config.infrastructure_name = "openstack"
      settings = partial_settings
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(settings)
      Bosh::Agent::Config.settings = settings

      @network_wrapper = Bosh::Agent::Platform::Ubuntu::Network.new
      Bosh::Agent::Util.should_receive(:update_file) do |contents, file|
        contents.should match /^prepend domain-name-servers 1\.2\.3\.4;$/
        file.should == "/etc/dhcp3/dhclient.conf"
        true # fake a change
      end
      @network_wrapper.should_receive(:restart_dhclient)
      @network_wrapper.setup_networking
    end
  end
end
