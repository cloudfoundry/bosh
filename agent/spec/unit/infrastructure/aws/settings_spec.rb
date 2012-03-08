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

  it 'should get network settings' do
    settings_wrapper = Bosh::Agent::Infrastructure::Aws::Settings.new
    network_settings = settings_wrapper.get_network_settings

    network_settings.should have_key("default")
    network_settings["default"].should have_key("ip")
    network_settings["default"].should have_key("netmask")
    network_settings["default"].should have_key("dns")
    network_settings["default"].should have_key("gateway")
  end

end
