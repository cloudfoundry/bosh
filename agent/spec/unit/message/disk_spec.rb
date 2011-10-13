require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::MigrateDisk do
  it 'should migrate disk' do
    #handler = Bosh::Agent::Message::MigrateDisk.process(["4", "9"])
  end
end

describe Bosh::Agent::Message::UnmountDisk do
  it 'should unmount disk' do
    Bosh::Agent::Message::DiskUtil.stub!(:lookup_disk_by_cid).and_return('/dev/sdy')
    Bosh::Agent::Message::DiskUtil.stub!(:mount_entry).and_return('/dev/sdy1 /foomount fstype')

    handler = Bosh::Agent::Message::UnmountDisk.new
    handler.stub!(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unmounted /dev/sdy1 on /foomount"}
  end

  it "should fall through if mount is not present" do
    Bosh::Agent::Message::DiskUtil.stub!(:lookup_disk_by_cid).and_return('/dev/sdx')
    Bosh::Agent::Message::DiskUtil.stub!(:mount_entry).and_return(nil)

    handler = Bosh::Agent::Message::UnmountDisk.new
    handler.stub!(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unknown mount for partition: /dev/sdx1" }
  end
end

describe Bosh::Agent::Message::DiskUtil do

  it "should lookup disks through settings" do
    settings = { "disks" => { "persistent" => { 199 => 2 }}}
    Bosh::Agent::Config.settings = settings

    dev_path = "/sys/bus/scsi/devices/2:0:2:0/block/sdc"
    Bosh::Agent::Message::DiskUtil.stub!(:detect_block_device).and_return(dev_path)

    Bosh::Agent::Message::DiskUtil.lookup_disk_by_cid(199).should == "/dev/sdc"
  end

  it "should raise exception if persistent disk cid is unknown" do
    settings = { "disks" => { "persistent" => { 199 => 2 }}}
    Bosh::Agent::Config.settings = settings

    lambda {
      Bosh::Agent::Message::DiskUtil.lookup_disk_by_cid(200)
    }.should raise_error(Bosh::Agent::MessageHandlerError, /Unknown persistent disk/)
  end

end

