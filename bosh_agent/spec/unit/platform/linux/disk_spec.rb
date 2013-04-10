# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/linux/disk'

describe Bosh::Agent::Platform::Linux::Disk do

  context 'vSphere' do

    let(:config)        { Bosh::Agent::Config }
    let(:store_path)    { File.join(Bosh::Agent::Config.base_dir, 'store') }
    let(:dev_path)      { '/sys/bus/scsi/devices/2:0:333:0/block/*' }
    let(:disk_wrapper)  {
      disk_w = Bosh::Agent::Platform::Linux::Disk.new
      disk_w.stub(:rescan_scsi_bus)
      disk_w
    }

    before(:each) do
      Bosh::Agent::Config.settings = { 'disks' => { 'persistent' => { 2 => '333'} } }
      Bosh::Agent::Config.infrastructure_name = 'vsphere'
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
    end

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

    it 'should raise exception if persistent disk cid is unknown' do
      settings = { 'disks' => { 'persistent' => { 199 => 2 }}}
      Bosh::Agent::Config.settings = settings

      lambda {
        disk_wrapper.lookup_disk_by_cid(200)
      }.should raise_error(Bosh::Agent::FatalError, /Unknown persistent disk/)
    end

    it 'mounts persistent disk to store_dir if not already mounted' do
      Dir.should_receive(:glob).with(dev_path, 0).and_return(['/dev/sdy'])
      File.should_receive(:blockdev?).with('/dev/sdy1').and_return(true)
      disk_wrapper.stub!(:mount_exists?).and_return false
      disk_wrapper.should_receive(:sh).with("mount /dev/sdy1 #{store_path}")

      disk_wrapper.mount_persistent_disk(2)
    end

    it 'mounts persistent disk only once' do
      Dir.should_receive(:glob).twice.with(dev_path, 0).and_return(['/dev/sdy'])
      File.should_receive(:blockdev?).twice.with('/dev/sdy1').and_return(true)
      disk_wrapper.should_receive(:mount_exists?).and_return false
      disk_wrapper.should_receive(:sh).with("mount /dev/sdy1 #{store_path}")

      disk_wrapper.mount_persistent_disk(2)

      disk_wrapper.should_receive(:mount_exists?).and_return true
      disk_wrapper.mount_persistent_disk(2)
    end
    it 'mounts only block devices' do
      Dir.should_receive(:glob).with(dev_path, 0).and_return(['/dev/sdy'])
      File.should_receive(:blockdev?).with('/dev/sdy1').and_return(false)
      disk_wrapper.should_not_receive(:mount_exists?)
      disk_wrapper.should_not_receive(:sh)

      disk_wrapper.mount_persistent_disk(2)
    end
  end

  context 'AWS' do
    before(:each) do
      Bosh::Agent::Config.settings = { 'disks' => { 'ephemeral' => '/dev/sdq',
                                                    'persistent' => { 2 => '/dev/sdf'} } }
      Bosh::Agent::Config.infrastructure_name = 'aws'
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil

    end

    it 'should get data disk device name' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)

      Dir.should_receive(:glob).with(%w(/dev/sdq /dev/vdq /dev/xvdq)).twice.and_return(%w(/dev/xvdq))
      disk_wrapper.get_data_disk_device_name.should == '/dev/xvdq'
    end

    it 'should look up disk by cid' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)

      Dir.should_receive(:glob).with(%w(/dev/sdf /dev/vdf /dev/xvdf)).twice.and_return(%w(/dev/xvdf))
      disk_wrapper.lookup_disk_by_cid(2).should == '/dev/xvdf'
    end
  end

  context 'OpenStack' do
    before(:each) do
      Bosh::Agent::Config.settings = { 'disks' => { 'ephemeral' => '/dev/sdq',
                                                    'persistent' => { 2 => '/dev/sdf'} } }
      Bosh::Agent::Config.infrastructure_name = 'openstack'
      Bosh::Agent::Config.instance_variable_set :@infrastructure, nil
    end

    it 'should get data disk device name' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)

      Dir.should_receive(:glob).with(%w(/dev/sdq /dev/vdq /dev/xvdq)).twice.and_return(%w(/dev/vdq))
      disk_wrapper.get_data_disk_device_name.should == '/dev/vdq'
    end

    it 'should look up disk by cid' do
      disk_wrapper = Bosh::Agent::Platform::Linux::Disk.new
      disk_wrapper.instance_variable_set(:@dev_path_timeout, 0)

      Dir.should_receive(:glob).with(%w(/dev/sdf /dev/vdf /dev/xvdf)).twice.and_return(%w(/dev/vdf))
      disk_wrapper.lookup_disk_by_cid(2).should == '/dev/vdf'
    end
  end

end
