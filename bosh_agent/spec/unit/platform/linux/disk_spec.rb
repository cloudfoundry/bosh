# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/linux/disk'

describe Bosh::Agent::Platform::Linux::Disk do

  context "vSphere" do
    before(:each) do
      Bosh::Agent::Config.settings = { 'disks' => { 'persistent' => { 2 => '333'} } }
      Bosh::Agent::Config.infrastructure_name = "vsphere"


    end
    let(:disk_wrapper) {
      disk_w = Bosh::Agent::Platform::Linux::Disk.new
      disk_w.stub(:rescan_scsi_bus)
      disk_w
    }
    let(:dev_path) { '/sys/bus/scsi/devices/2:0:333:0/block/*' }


    it 'should look up disk by cid' do
      Dir.should_receive(:glob).with(dev_path, 0).and_return(['/dev/sdy'])
      disk_wrapper.lookup_disk_by_cid(2).should eq '/dev/sdy'
    end

    it 'should retry disk lookup by cid' do
      disk_wrapper.instance_variable_set(:@disk_retry_timeout, 2)
      Dir.should_receive(:glob).with(dev_path, 0).exactly(2).and_return([])
      lambda {
        disk_wrapper.lookup_disk_by_cid(2)
      }.should raise_error Bosh::Agent::DiskNotFoundError
    end

    it 'should get data disk device name' do
      disk_wrapper.get_data_disk_device_name.should eq '/dev/sdb'
    end

    it "should raise exception if persistent disk cid is unknown" do
      settings = { "disks" => { "persistent" => { 199 => 2 }}}
      Bosh::Agent::Config.settings = settings

      lambda {
        disk_wrapper.lookup_disk_by_cid(200)
      }.should raise_error(Bosh::Agent::FatalError, /Unknown persistent disk/)
    end
  end

  context "AWS" do
    before(:each) do
      Bosh::Agent::Config.settings = { 'disks' => { 'ephemeral' => "/dev/sdq",
                                                    'persistent' => { 2 => '/dev/sdf'} } }
      Bosh::Agent::Config.infrastructure_name = "aws"
    end

    it 'should get data disk device name' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)
      lambda {
        disk_wrapper.get_data_disk_device_name.should == '/dev/sdq'
      }.should raise_error(Bosh::Agent::FatalError, /"\/dev\/sdq", "\/dev\/vdq", "\/dev\/xvdq"/)
    end

    it 'should look up disk by cid' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)
      lambda {
        disk_wrapper.lookup_disk_by_cid(2).should == '/dev/sdf'
      }.should raise_error(Bosh::Agent::FatalError, /"\/dev\/sdf", "\/dev\/vdf", "\/dev\/xvdf"/)
    end
  end

  context "OpenStack" do
    before(:each) do
      Bosh::Agent::Config.settings = { 'disks' => { 'ephemeral' => "/dev/sdq",
                                                    'persistent' => { 2 => '/dev/sdf'} } }
      Bosh::Agent::Config.infrastructure_name = "openstack"
    end

    it 'should get data disk device name' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)
      lambda {
        disk_wrapper.get_data_disk_device_name.should == '/dev/vdq'
      }.should raise_error(Bosh::Agent::FatalError, /"\/dev\/sdq", "\/dev\/vdq", "\/dev\/xvdq"/)
    end

    it 'should look up disk by cid' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)
      lambda {
        disk_wrapper.lookup_disk_by_cid(2).should == '/dev/vdf'
      }.should raise_error(Bosh::Agent::FatalError, /"\/dev\/sdf", "\/dev\/vdf", "\/dev\/xvdf"/)
    end
  end

end
