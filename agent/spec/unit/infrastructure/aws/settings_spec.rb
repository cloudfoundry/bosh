require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Infrastructure.new("aws").infrastructure

describe Bosh::Agent::Infrastructure::Aws::Settings do

  before(:each) do
    Bosh::Agent::Config.settings_file = File.join(base_dir, 'settings.json')
    @settings = {"vm" => "test_vm", "disks" => "test_disks"}
  end

  it 'should load settings' do
    Bosh::Agent::Infrastructure::Aws::Registry.stub(:get_settings).and_return(@settings)
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    settings = settings_wrapper.load_settings
    settings.should == @settings
  end

  it 'should get network settings for dhcp network' do
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_properties = {"type" => "dynamic"}
    properties = settings_wrapper.get_network_settings("test", network_properties)

    properties.should have_key("ip")
    properties.should have_key("netmask")
    properties.should have_key("dns")
    properties.should have_key("gateway")
  end

  it 'should get nothing for vip network' do
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_properties = {"type" => "vip"}
    properties = settings_wrapper.get_network_settings("test", network_properties)
    properties.should be_nil
  end

  it 'should raise unsupported network exception for manual network' do
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_properties = {}
    lambda {
      properties = settings_wrapper.get_network_settings("test", network_properties)
    }.should raise_error(Bosh::Agent::StateError, /Unsupported network/)
  end

end
