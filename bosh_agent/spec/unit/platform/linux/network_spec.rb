# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Platform::Linux::Network do

  class FakeNetwork < described_class
    attr_reader :wrote_dhcp_conf, :wrote_network_interfaces
    def write_dhcp_conf
      @wrote_dhcp_conf = true
    end

    def write_network_interfaces
      @wrote_network_interfaces = true
    end
  end

  let(:microbosh_network) do
    {
        "netmask" => "255.255.248.0",
        "mac" => "00:50:56:89:17:70",
        "ip" => "172.30.40.115",
        "default" => ["gateway", "dns"],
        "gateway" => nil,
        "dns" => nil,
        "cloud_properties" => {
            "name" => "VLAN440"
        }
    }
  end

  let(:complete_network) do
    {
        "netmask" => "255.255.248.0",
        "mac" => "00:50:56:89:17:70",
        "ip" => "172.30.40.115",
        "default" => ["gateway", "dns"],
        "gateway" => "172.30.40.1",
        "dns" => ["172.30.22.153", "172.30.22.154"],
        "cloud_properties" => {
            "name" => "VLAN440"
        }
    }
  end
  let(:partial_network) do
    {
        "dns" => ["1.2.3.4", "5.6.7.8"],
        "default" => ["gateway", "dns"]
    }
  end
  let(:complete_settings) do
    {
        "vm" => {
            "name" => "vm-273a202e-eedf-4475-a4a1-66c6d2628742",
            "id" => "vm-51290"
        },
        "disks" => {
            "ephemeral" => 1,
            "persistent" => {
                "250" => 2
            },
            "system" => 0
        },
        "mbus" => "nats://user:pass@11.0.0.11:4222",
        "networks" => {
            "network_a" => complete_network
        },
        "blobstore" => {
            "provider" => "simple",
            "options" => {
                "password" => "Ag3Nt",
                "user" => "agent",
                "endpoint" => "http://172.30.40.11:25250"
            }
        },
        "ntp" => ["ntp01.las01.emcatmos.com", "ntp02.las01.emcatmos.com"],
        "agent_id" => "a26efbe5-4845-44a0-9323-b8e36191a2c8"
    }
  end

  let(:partial_settings) do
    {
        "networks" => {
            "default" => partial_network
        }
    }
  end

  let(:network_wrapper) { FakeNetwork.new(nil) }

  before(:each) do
    Bosh::Agent::Config.infrastructure_name = "vsphere"
    Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
    Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(complete_settings)
    Bosh::Agent::Config.settings = complete_settings

    # We just want to avoid this to accidentally be invoked on dev systems
    Bosh::Agent::Util.stub(:update_file)
    network_wrapper.stub(:gratuitous_arp)
  end

  context "parse dns" do
    it "does not parse DNS when network isn't configured with default dns" do
      config = complete_settings["networks"]["network_a"]
      config['default'] -= ['dns']

      network_wrapper.dns.should == []
    end

    it "does not parse DNS when there's no 'default' network config" do
      config = complete_settings["networks"]["network_a"]
      config.delete('default')

      network_wrapper.dns.should == []
    end

    it "does not parse DNS when DNS config is explicitly null" do
      complete_settings["networks"]["network_a"] = microbosh_network

      network_wrapper.dns.should == []
    end

    it "parses dns from network settings" do
      network_wrapper.dns.should == ["172.30.22.153", "172.30.22.154"]
    end
  end

  context "dhcp network settings" do
    context "when there's a single network" do
      it "sets network settings" do
        network_wrapper.setup_dhcp_from_settings
        network_wrapper.wrote_dhcp_conf.should be(true)
        network_wrapper.dns.should == ["172.30.22.153", "172.30.22.154"]
      end
    end

    context "when there are multiple networks" do
      it "picks the dns from the 'default' network" do
        Bosh::Agent::Config.settings["networks"].merge!(partial_settings["networks"])
        Bosh::Agent::Config.settings["networks"]["network_a"].delete("default")
        network_wrapper.setup_dhcp_from_settings
        network_wrapper.wrote_dhcp_conf.should be(true)
        network_wrapper.dns.should == ["1.2.3.4", "5.6.7.8"]
      end
    end
  end

  context "Unsupported Infrastructure" do
    before do
      Bosh::Agent::Config.infrastructure_name = "something not supported"
    end

    it "should raise an exception when trying to set up networking" do
      expect {
        network_wrapper.setup_networking
      }.to raise_error(Bosh::Agent::FatalError, /unsupported infrastructure something not supported/)
    end
  end

  context "vSphere" do
    before do
      network_wrapper.stub(:detect_mac_addresses).and_return({"00:50:56:89:17:70" => "eth0"})
    end

    it "should fail when the mac address in the spec does not match the instance" do
      complete_network["mac"] = "foobar"
      expect {
        network_wrapper.setup_networking
      }.to raise_error(Bosh::Agent::FatalError, /foobar from settings not present in instance/)
    end

    it "should raise an exception when cidr can not be generated from ip and netmask" do
      complete_network["netmask"] = ""
      expect {
        network_wrapper.setup_networking
      }.to raise_error(Bosh::Agent::FatalError, "172.30.40.115  is invalid (contains invalid characters).")
    end

    it "should delegate updating the network interface files to the platform implementation" do
      network_wrapper.setup_networking
      network_wrapper.wrote_network_interfaces.should be(true)
    end

    it "should update the resolv.conf file" do
      Bosh::Agent::Util.should_receive(:update_file) do |result, file_path|
        result.should == "nameserver 172.30.22.153\nnameserver 172.30.22.154\n"
        file_path.should == '/etc/resolv.conf'
      end
      network_wrapper.setup_networking
    end
  end

  context "AWS" do
    it "should delegate DHCP configuration to platform implementation" do
      Bosh::Agent::Config.infrastructure_name = "aws"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(partial_settings)
      Bosh::Agent::Config.settings = partial_settings

      network_wrapper.setup_networking
      network_wrapper.wrote_dhcp_conf.should be(true)
    end
  end

  context "OpenStack" do
    it "should delegate DHCP configuration to platform implementation" do
      Bosh::Agent::Config.infrastructure_name = "openstack"
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
      Bosh::Agent::Config.infrastructure.stub(:load_settings).and_return(partial_settings)
      Bosh::Agent::Config.settings = partial_settings

      network_wrapper.setup_networking
      network_wrapper.wrote_dhcp_conf.should be(true)
    end
  end
end
