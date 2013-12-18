# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

Bosh::Agent::Infrastructure.new("cloudstack").infrastructure

describe Bosh::Agent::Infrastructure::Cloudstack::Settings do
  let(:cloudstack_settings) { Bosh::Agent::Infrastructure::Cloudstack::Settings.new }

  describe :get_settings do
    let(:settings) { {"vm" => "test_vm", "disks" => "test_disks"} }

    it "should load settings" do
      cloudstack_settings.should_receive(:setup_openssh_key)
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_settings).and_return(settings)

      loaded_settings = cloudstack_settings.load_settings
      loaded_settings.should == settings
    end
  end

  describe :setup_openssh_key do
    let(:test_authorized_keys) { File.join(Dir.mktmpdir, "test_auth") }

    it "should setup the public OpenSSH key" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_openssh_key).and_return("test_key")
      cloudstack_settings.stub(:authorized_keys).and_return(test_authorized_keys)
      FileUtils.should_receive(:mkdir_p).with(File.dirname(test_authorized_keys))
      FileUtils.should_receive(:chmod).twice.and_return(true)
      FileUtils.should_receive(:chown).twice.and_return(true)

      cloudstack_settings.setup_openssh_key
      File.open(test_authorized_keys, "r") { |f| f.read.should == "test_key" }
    end

    it "should do nothing if registry doesn't returns a public OpenSSH key" do
      Bosh::Agent::Infrastructure::Cloudstack::Registry.should_receive(:get_openssh_key).and_return(nil)
      FileUtils.should_not_receive(:mkdir_p)
      FileUtils.should_not_receive(:chown)

      cloudstack_settings.setup_openssh_key
    end
  end

  describe :get_network_settings do
    it "should raise unsupported network exception for unknown  network" do
      network_properties = { "type" => "unknown" }
      expect {
        network_settings = cloudstack_settings.get_network_settings("test", network_properties)
      }.to raise_error Bosh::Agent::StateError, /Unsupported network type/
    end

    it "should get nothing for vip networks" do
      network_properties = { "type" => "vip" }
      network_settings = cloudstack_settings.get_network_settings("test", network_properties)
      network_settings.should be_nil
    end

    it "should get network settings for dhcp networks" do
      net_info = double("net_info", default_gateway_interface: "eth0",
                                    default_gateway: "1.2.3.1",
                                    primary_dns: "1.1.1.1",
                                    secondary_dns: "2.2.2.2")
      Bosh::Agent::Util.should_receive(:get_network_info).and_return(net_info)

      network_properties = { "type" => "dynamic" }
      network_settings = cloudstack_settings.get_network_settings("test", network_properties)
      network_settings.should_not be_nil
    end
  end
end
