# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Infrastructure.new("warden").infrastructure

describe Bosh::Agent::Infrastructure::Warden::Settings do

  context "successful cases" do

    before :each do
      Bosh::Agent::Config.settings_file = File.join(base_dir, 'bosh', 'settings.json')
      @settings = Bosh::Agent::Infrastructure::Warden::Settings.new

      FileUtils.mkdir_p(File.join(base_dir, 'bosh'))
      File.open(Bosh::Agent::Config.settings_file, 'w') do |f|
        f.write(settings_json)
      end
    end

    after :each do
      File.truncate(Bosh::Agent::Config.settings_file, 0)
    end

    it "can load settings" do
      @settings.load_settings.should == Yajl::Parser.parse(settings_json)
    end

  end

  context "failed cases" do

    it "should raise error when the setting file is missing" do
      Bosh::Agent::Config.settings_file = File.join(base_dir, 'bosh', 'missing.json')
      @settings = Bosh::Agent::Infrastructure::Warden::Settings.new

      expect {
        @settings.load_settings
      }.to raise_error Bosh::Agent::LoadSettingsError
    end

  end

  def settings_json
    %q[{"vm":{"name":"vm-273a202e-eedf-4475-a4a1-66c6d2628742","id":"vm-51290"},"disks":{"ephemeral":1,"persistent":{"250":2},"system":0},"mbus":"nats://user:pass@11.0.0.11:4222","networks":{"network_a":{"netmask":"255.255.248.0","mac":"00:50:56:89:17:70","ip":"172.30.40.115","default":["gateway","dns"],"gateway":"172.30.40.1","dns":["172.30.22.153","172.30.22.154"],"cloud_properties":{"name":"VLAN440"}}},"blobstore":{"plugin":"simple","properties":{"password":"Ag3Nt","user":"agent","endpoint":"http://172.30.40.11:25250"}},"ntp":["ntp01.las01.emcatmos.com","ntp02.las01.emcatmos.com"],"agent_id":"a26efbe5-4845-44a0-9323-b8e36191a2c8"}]
  end
end
