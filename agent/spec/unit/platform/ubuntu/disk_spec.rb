# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.platform_name = "ubuntu"
Bosh::Agent::Config.platform

describe Bosh::Agent::Platform::Ubuntu::Disk do

  def vsphere_setup
    Bosh::Agent::Config.settings = { 'disks' => { 'persistent' => { 2 => '333'} } }
    Bosh::Agent::Config.infrastructure_name = "vsphere"
  end

  it 'should look up disk by cid' do
    vsphere_setup
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    disk_wrapper.stub(:detect_block_device).and_return('/sys/long/bus/scsi/path/sdy')
    disk_wrapper.lookup_disk_by_cid(2).should == '/dev/sdy'
  end

  it 'should get data disk device name' do
    vsphere_setup
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    disk_wrapper.get_data_disk_device_name.should == '/dev/sdb'
  end

  it "should raise exception if persistent disk cid is unknown" do
    vsphere_setup
    settings = { "disks" => { "persistent" => { 199 => 2 }}}
    Bosh::Agent::Config.settings = settings

    lambda {
      disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
      disk_wrapper.lookup_disk_by_cid(200)
    }.should raise_error(Bosh::Agent::FatalError, /Unknown persistent disk/)
  end

  def aws_setup
    Bosh::Agent::Config.settings = { 'disks' => { 'ephemeral' => "/dev/sdq",
                                                  'persistent' => { 2 => '/dev/sdf'} } }
    Bosh::Agent::Config.infrastructure_name = "aws"
  end

  it 'should get data disk device name' do
    aws_setup
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    disk_wrapper.stub(:dev_path_timeout).and_return(1)
    lambda {
      disk_wrapper.get_data_disk_device_name.should == '/dev/sdq'
    }.should raise_error(Bosh::Agent::FatalError, /\/dev\/sdq or \/dev\/xvdq/)
  end

  it 'should look up disk by cid' do
    aws_setup
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    disk_wrapper.stub(:dev_path_timeout).and_return(1)
    lambda {
      disk_wrapper.lookup_disk_by_cid(2).should == '/dev/sdf'
    }.should raise_error(Bosh::Agent::FatalError, /\/dev\/sdf or \/dev\/xvdf/)
  end

  def openstack_setup
    Bosh::Agent::Config.settings = { 'disks' => { 'ephemeral' => "/dev/sdq",
                                                  'persistent' => { 2 => '/dev/sdf'} } }
    Bosh::Agent::Config.infrastructure_name = "openstack"
  end

  it 'should get data disk device name' do
    openstack_setup
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    disk_wrapper.stub(:dev_path_timeout).and_return(1)
    lambda {
      disk_wrapper.get_data_disk_device_name.should == '/dev/vdq'
    }.should raise_error(Bosh::Agent::FatalError, /\/dev\/sdq or \/dev\/vdq/)
  end

  it 'should look up disk by cid' do
    openstack_setup
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    disk_wrapper.stub(:dev_path_timeout).and_return(1)
    lambda {
      disk_wrapper.lookup_disk_by_cid(2).should == '/dev/vdf'
    }.should raise_error(Bosh::Agent::FatalError, /\/dev\/sdf or \/dev\/vdf/)
  end

end
