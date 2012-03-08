require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.infrastructure_name = "vsphere"
Bosh::Agent::Config.infrastructure

describe Bosh::Agent::Infrastructure::Vsphere::Disk do

  before(:each) do
    Bosh::Agent::Config.settings = { 'disks' => { 'persistent' => { 2 => '333'} } }
  end

  it 'should look up disk by cid' do
    disk_wrapper = Bosh::Agent::Infrastructure::Vsphere::Disk.new
    disk_wrapper.stub(:detect_block_device).and_return('/sys/long/bus/scsi/path/sdy')
    disk_wrapper.lookup_disk_by_cid(2).should == '/dev/sdy'
  end

  it 'should get data disk device name' do
    disk_wrapper = Bosh::Agent::Infrastructure::Vsphere::Disk.new
    disk_wrapper.get_data_disk_device_name.should == '/dev/sdb'
  end

  it "should raise exception if persistent disk cid is unknown" do
    settings = { "disks" => { "persistent" => { 199 => 2 }}}
    Bosh::Agent::Config.settings = settings

    lambda {
      disk_wrapper = Bosh::Agent::Infrastructure::Vsphere::Disk.new
      disk_wrapper.lookup_disk_by_cid(200)
    }.should raise_error(Bosh::Agent::FatalError, /Unknown persistent disk/)
  end

end
