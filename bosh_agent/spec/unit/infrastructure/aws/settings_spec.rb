# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Infrastructure.new("aws").infrastructure

describe Bosh::Agent::Infrastructure::Aws::Settings do
  before(:all) do
    @test_authorized_dir = Dir.mktmpdir
    @test_authorized_keys = File.join(@test_authorized_dir, "test_auth")
  end

  before(:each) do
    Bosh::Agent::Config.settings_file = File.join(base_dir, 'settings.json')
    @settings = {"vm" => "test_vm", "disks" => "test_disks"}
  end

  it 'should load settings' do
    Bosh::Agent::Infrastructure::Aws::Registry.stub(:get_settings).and_return(@settings)
    Bosh::Agent::Infrastructure::Aws::Registry.stub(:get_openssh_key).and_return("test_key")
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    settings_wrapper.stub(:authorized_keys).and_return(@test_authorized_keys)
    FileUtils.stub(:chown).and_return(true)
    settings = settings_wrapper.load_settings
    settings.should == @settings
  end

  it 'should get network settings for dhcp network' do
    default_gateway = '1.2.3.1'
    primary_dns = '1.1.1.1'
    secondary_dns = '2.2.2.2'
    ip = '1.2.3.4'
    netmask = '255.255.255.0'

    ohai_network = {
        interfaces: {
            "eth0" => {
                addresses: {
                    ip => {
                        family: "inet",
                        netmask: netmask
                    }
                }
            }
        },
        default_interface: "eth0",
        default_gateway: default_gateway
    }

    ohai_system = double(Ohai::System, all_plugins: true)
    Ohai::System.stub(new: ohai_system)
    ohai_system.stub(:network).and_return(ohai_network)

    Resolv::DNS::Config.stub(default_config_hash: {nameserver: [primary_dns, secondary_dns]})

    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_properties = {"type" => "dynamic"}
    properties = settings_wrapper.get_network_settings("test", network_properties)

    properties["ip"].should == ip
    properties["netmask"].should == netmask
    properties["dns"].should == [primary_dns, secondary_dns]
    properties["gateway"].should == default_gateway
  end

  it 'should get nothing for vip network' do
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_properties = {"type" => "vip"}
    properties = settings_wrapper.get_network_settings("test", network_properties)
    properties.should be_nil
  end

  it 'should raise unsupported network exception for unknown network' do
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    expect {
      settings_wrapper.get_network_settings("test", {"type" => "unknown"})
    }.to raise_error(Bosh::Agent::StateError, /Unsupported network type 'unknown'/)
  end

  it 'should setup the ssh public key' do
    Bosh::Agent::Infrastructure::Aws::Registry.stub!(:get_openssh_key).and_return("test_key")
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    settings_wrapper.stub(:authorized_keys).and_return(@test_authorized_keys)
    FileUtils.stub(:chown).and_return(true)
    settings_wrapper.setup_openssh_key
    File.open(@test_authorized_keys, "r") { |f| f.read.should == "test_key" }
  end

end
