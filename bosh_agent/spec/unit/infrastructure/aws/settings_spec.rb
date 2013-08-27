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
    net_info = double('net_info', default_gateway_interface: 'eth0', default_gateway: '1.2.3.1',
                      primary_dns: '1.1.1.1', secondary_dns: '2.2.2.2')
    net_interface_config = double('net_interface_config', address:'1.2.3.4', netmask: '255.255.255.0')
    sigar = double(Sigar, net_info: net_info, net_interface_config: net_interface_config, :logger= => nil)
    Sigar.stub(new: sigar)
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_properties = {"type" => "dynamic"}
    properties = settings_wrapper.get_network_settings("test", network_properties)

    properties.should have_key("ip")
    properties.should have_key("netmask")
    properties.should_not have_key("dns")
    properties.should have_key("gateway")
  end

  it 'should get nothing for manual network' do
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_properties = {}
    properties = settings_wrapper.get_network_settings("test", network_properties)
    properties.should be_nil
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
    Bosh::Agent::Infrastructure::Aws::Registry.stub(:get_openssh_key).and_return("test_key")
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    settings_wrapper.stub(:authorized_keys).and_return(@test_authorized_keys)
    FileUtils.stub(:chown).and_return(true)
    settings_wrapper.setup_openssh_key
    File.open(@test_authorized_keys, "r") { |f| f.read.should == "test_key" }
  end

end
