require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.platform_name = "ubuntu"
Bosh::Agent::Config.platform

describe Bosh::Agent::Platform::Ubuntu::Disk do

  before(:each) do
    Bosh::Agent::Config.settings = { 'disks' => { 'persistent' => { 2 => '333'} } }
  end

  it 'should mount persistent disk' do
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    File.stub(:blockdev?).and_return(true)
    disk_wrapper.stub(:mount_entry).and_return(nil)
    disk_wrapper.stub(:mount)
    disk_wrapper.stub(:detect_block_device).and_return('/sys/long/bus/scsi/path/sdy')
    disk_wrapper.mount_persistent_disk(2)
  end

  it 'should look up disk by cid' do
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    disk_wrapper.stub(:detect_block_device).and_return('/sys/long/bus/scsi/path/sdy')
    disk_wrapper.lookup_disk_by_cid(2).should == '/dev/sdy'
  end

end
