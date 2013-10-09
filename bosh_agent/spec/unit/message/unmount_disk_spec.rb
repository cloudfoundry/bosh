require 'spec_helper'

describe Bosh::Agent::Message::UnmountDisk do
  it 'should unmount disk' do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return("/dev/sdy")
    Bosh::Agent::DiskUtil.stub(:mount_entry).and_return('/dev/sdy1 /foomount fstype')

    handler = Bosh::Agent::Message::UnmountDisk.new
    Bosh::Agent::DiskUtil.stub(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unmounted /dev/sdy1 on /foomount"}
  end

  it "should fall through if mount is not present" do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return("/dev/sdx")
    Bosh::Agent::DiskUtil.stub(:mount_entry).and_return(nil)

    handler = Bosh::Agent::Message::UnmountDisk.new
    handler.stub(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unknown mount for partition: /dev/sdx1" }
  end
end
