# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Platform::Ubuntu::Network do
  let(:template_dir) { 'lib/bosh_agent/platform/ubuntu/templates' }
  let(:network_wrapper) { described_class.new(template_dir) }
  let(:complete_settings) do
    settings_json = %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"plugin":"simple","properties":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
    Yajl::Parser.new.parse(settings_json)
  end

  context "vSphere" do
    before do
      Bosh::Agent::Config.infrastructure_name = "vsphere"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)
      Bosh::Agent::Config.settings = complete_settings

      Bosh::Agent::Util.stub(:update_file)
      network_wrapper.stub(:gratuitous_arp)
      network_wrapper.stub(detect_mac_addresses: {"00:50:56:89:17:70" => "eth0"})
    end

    it "should generate ubuntu network files" do
      Bosh::Agent::Util.should_receive(:update_file) do |data, file|
        data.should == "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet static\n    address 172.30.40.115\n    network 172.30.40.0\n    netmask 255.255.248.0\n    broadcast 172.30.47.255\n    gateway 172.30.40.1\n\n"
        file.should == "/etc/network/interfaces"
      end
      network_wrapper.should_receive("sh").with("service network-interface stop INTERFACE=eth0").and_return(double.as_null_object)
      network_wrapper.should_receive("sh").with("service network-interface start INTERFACE=eth0").and_return(double.as_null_object)

      network_wrapper.setup_networking
    end
  end

  context "AWS" do
    let(:partial_settings) do
      json = %q[{"networks":{"default":{"dns":["1.2.3.4","5.6.7.8"],"default":["gateway","dns"]}}]
      Yajl::Parser.new.parse(json)
    end

    before do
      Bosh::Agent::Config.infrastructure_name = "aws"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(partial_settings)
      Bosh::Agent::Config.settings = partial_settings
    end

    it "should configure dhcp with dns server prepended" do
      Bosh::Agent::Util.should_receive(:update_file) do |contents, file|
        contents.should match /^prepend domain-name-servers 5\.6\.7\.8;\nprepend domain-name-servers 1\.2\.3\.4;$/
        file.should == "/etc/dhcp3/dhclient.conf"
        true # fake a change
      end
      network_wrapper.should_receive(:restart_dhclient)

      network_wrapper.setup_networking
    end
  end

  context "OpenStack" do
    let(:partial_settings) do
      json = %q[{"networks":{"default":{"dns":["1.2.3.4"],"default":["gateway","dns"]}}]
      Yajl::Parser.new.parse(json)
    end

    before do
      Bosh::Agent::Config.infrastructure_name = "openstack"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(partial_settings)
      Bosh::Agent::Config.settings = partial_settings
    end

    it "should configure dhcp with dns server prepended" do
      Bosh::Agent::Util.should_receive(:update_file) do |contents, file|
        contents.should match /^prepend domain-name-servers 1\.2\.3\.4;$/
        file.should == "/etc/dhcp3/dhclient.conf"
        true # fake a change
      end
      network_wrapper.should_receive(:restart_dhclient)

      network_wrapper.setup_networking
    end
  end

  context "CloudStack" do
    let(:partial_settings) do
      json = %q[{"networks":{"default":{"dns":["1.2.3.4"],"default":["gateway","dns"]}}]
      Yajl::Parser.new.parse(json)
    end

    before do
      Bosh::Agent::Config.infrastructure_name = "cloudstack"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(partial_settings)
      Bosh::Agent::Config.settings = partial_settings
    end

    it "should configure dhcp with dns server prepended" do
      Bosh::Agent::Util.should_receive(:update_file) do |contents, file|
        contents.should match /^prepend domain-name-servers 1\.2\.3\.4;$/
        file.should == "/etc/dhcp3/dhclient.conf"
        true # fake a change
      end
      network_wrapper.should_receive(:restart_dhclient)

      network_wrapper.setup_networking
    end
  end
end
