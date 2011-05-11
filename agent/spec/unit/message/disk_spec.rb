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
    handler.stub!(:lsof_guard)
    handler.stub!(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unmounted /dev/sdy1 on /foomount"}
  end

  it "should fall through if mount is not present" do
    Bosh::Agent::Message::DiskUtil.stub!(:lookup_disk_by_cid).and_return('/dev/sdx')
    Bosh::Agent::Message::DiskUtil.stub!(:mount_entry).and_return(nil)

    handler = Bosh::Agent::Message::UnmountDisk.new
    handler.stub!(:lsof_guard)
    handler.stub!(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unknown mount for partition: /dev/sdx1" }
  end
end

