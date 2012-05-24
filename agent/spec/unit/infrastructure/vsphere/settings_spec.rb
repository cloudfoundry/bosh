# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.infrastructure_name = "vsphere"
Bosh::Agent::Config.infrastructure

describe Bosh::Agent::Infrastructure::Vsphere::Settings do

  before(:each) do
    Bosh::Agent::Config.settings_file = File.join(base_dir, 'bosh', 'settings.json')
    @settings = Bosh::Agent::Infrastructure::Vsphere::Settings.new
    @settings.cdrom_retry_wait = 0.1

    @settings.stub!(:mount_cdrom)
    @settings.stub!(:eject_cdrom)
    @settings.stub!(:udevadm_settle)
    @settings.stub!(:read_cdrom_byte)
  end

  it 'should load settings' do
    cdrom_dir = File.join(base_dir, 'bosh', 'settings')
    env = File.join(cdrom_dir, 'env')

    FileUtils.mkdir_p(cdrom_dir)
    File.open(env, 'w') { |f| f.write(settings_json) }

    @settings.load_settings.should == Yajl::Parser.new.parse(settings_json)
  end

  it 'should write env to settings file' do
    cdrom_dir = File.join(base_dir, 'bosh', 'settings')
    env = File.join(cdrom_dir, 'env')

    FileUtils.mkdir_p(cdrom_dir)
    File.open(env, 'w') { |f| f.write(settings_json) }

    data = @settings.load_settings

    settings_file = File.join(base_dir, 'bosh', 'settings.json')
    settings_json_from_file = File.read(settings_file)

    settings_json_from_file.should == settings_json
    data.should == Yajl::Parser.new.parse(settings_json_from_file)
  end

  it 'should fall back to load settings from file' do
    @settings.stub!(:check_cdrom).and_raise(Bosh::Agent::LoadSettingsError)

    FileUtils.mkdir_p(File.join(base_dir, 'bosh'))
    settings_file = File.join(base_dir, 'bosh', 'settings.json')

    File.open(settings_file, 'w') { |f| f.write(settings_json) }

    @settings.load_settings.should == Yajl::Parser.new.parse(settings_json)
  end

  it "should fail when there is no cdrom" do
    @settings.stub!(:read_cdrom_byte).and_raise(Errno::ENOMEDIUM)
    lambda {
      @settings.check_cdrom
    }.should raise_error(Bosh::Agent::LoadSettingsError)
  end

  it "should fail when cdrom is busy" do
    @settings.stub!(:read_cdrom_byte).and_raise(Errno::EBUSY)
    lambda {
      @settings.check_cdrom
    }.should raise_error(Bosh::Agent::LoadSettingsError)
  end

  it 'should return nil when asked for network settings' do
    properties = Bosh::Agent::Config.infrastructure.get_network_settings("test", {})
    properties.should be_nil
  end

  def settings_json
    %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"plugin":"simple","properties":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
  end

end
