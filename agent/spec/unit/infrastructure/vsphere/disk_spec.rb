require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.infrastructure_name = "vsphere"
Bosh::Agent::Config.infrastructure

describe Bosh::Agent::Infrastructure::Vsphere::Disk do

  before(:each) do
    Bosh::Agent::Config.settings = { 'disks' => { 'persistent' => { 2 => '333'} } }
  end

  it 'should mount persistent disk' do
    disk_wrapper = Bosh::Agent::Infrastructure::Vsphere::Disk.new
    File.stub(:blockdev?).and_return(true)
    disk_wrapper.stub(:mount_entry).and_return(nil)
    disk_wrapper.stub(:mount)
    disk_wrapper.stub(:detect_block_device).and_return('/sys/long/bus/scsi/path/sdy')
    disk_wrapper.mount_persistent_disk(2)
  end

  it 'should look up disk by cid' do
    disk_wrapper = Bosh::Agent::Infrastructure::Vsphere::Disk.new
    disk_wrapper.stub(:detect_block_device).and_return('/sys/long/bus/scsi/path/sdy')
    disk_wrapper.lookup_disk_by_cid(2).should == '/dev/sdy'
  end

  it "should swap on data disk" do
    Bosh::Agent::Util.stub(:block_device_size).and_return(7903232)
    disk_wrapper = Bosh::Agent::Infrastructure::Vsphere::Disk.new
    disk_wrapper.stub(:mem_total).and_return(3951616)
    disk_wrapper.data_sfdisk_input.should == ",3859,S\n,,L\n"
  end

end
