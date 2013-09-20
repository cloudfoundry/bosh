# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Message::MigrateDisk do
  let(:platform) { double('platform') }
  let(:old_mountpoint) { double('old mountpoint', mountpoint?: false) }
  let(:new_mountpoint) { double('new mountpoint', mountpoint?: false) }

  before do
    Bosh::Agent::Config.settings = {'disks' => {
      'ephemeral' => '/dev/sdq',
      'persistent' => {
        'old_disk_cid' => '/dev/sda',
        'new_disk_cid' => '/dev/sdb'
      }
    }}
    Bosh::Agent::Config.platform_name = 'ubuntu'
    Bosh::Agent::Config.infrastructure_name = 'openstack'
    Bosh::Agent::Config.stub(platform: platform)

    Dir.stub(:glob).with(['/dev/sda', '/dev/vda', '/dev/xvda']).and_return(['/dev/sda'])
    Dir.stub(:glob).with(['/dev/sdb', '/dev/vdb', '/dev/xvdb']).and_return(['/dev/sdb'])

    @mount_path = File.join(Bosh::Agent::Config.base_dir, 'store')
    @migration_mount_path = File.join(Bosh::Agent::Config.base_dir, 'store_migraton_target') # (sic)

    Pathname.stub(:new).with(@mount_path).and_return(old_mountpoint)
    Pathname.stub(:new).with(@migration_mount_path).and_return(new_mountpoint)
  end

  context "when the new disk is mounted by a previous mount_disk message" do
    let(:old_disk) { double('disk', partition_path: nil) }
    let(:fake_migrator) { double('migrator') }

    before do
      old_mountpoint.stub(mountpoint?: true)
      new_mountpoint.stub(mountpoint?: true)
    end

    it 'should migrate to the new persistent disk' do
      # Remount old disk as read-only
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).with(@mount_path).ordered
      platform.stub(:find_disk_by_cid).with('old_disk_cid').and_return(old_disk)
      old_disk.should_receive(:mount).with(@mount_path, '-o ro').ordered.and_return(true)

      # copy shit over
      Bosh::Agent::DirCopier.stub(:new).with(@mount_path, @migration_mount_path).and_return(fake_migrator)
      fake_migrator.should_receive(:copy).with().ordered

      # Unmount all disks
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).with(@mount_path).ordered
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).with(@migration_mount_path).ordered

      # Remount new disk
      new_disk = double('new disk', partition_path: nil)
      platform.stub(:find_disk_by_cid).with('new_disk_cid').and_return(new_disk)
      new_disk.should_receive(:mount).with(@mount_path, '').ordered.and_return(true)

      Bosh::Agent::Message::MigrateDisk.process(['old_disk_cid', 'new_disk_cid'])
    end
  end

  context "when the new persistent disk is not mounted" do
    let(:old_disk) { double('disk', partition_path: nil) }

    before do
      new_mountpoint.stub(mountpoint?: false)
    end

    it 'does not migrate data if either disk is not mounted' do
      # Remount old disk as read-only
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).with(@mount_path).ordered
      platform.stub(:find_disk_by_cid).with('old_disk_cid').and_return(old_disk)
      old_disk.should_receive(:mount).with(@mount_path, '-o ro').ordered.and_return(true)

      # new disk not mounted, don't copy
      Bosh::Agent::DirCopier.should_not_receive(:new)

      # Unmount all disks
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).with(@mount_path).ordered
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).with(@migration_mount_path).ordered

      # Remount new disk
      new_disk = double('new disk', partition_path: nil)
      platform.stub(:find_disk_by_cid).with('new_disk_cid').and_return(new_disk)
      new_disk.should_receive(:mount).with(@mount_path, '').ordered.and_return(true)

      Bosh::Agent::Message::MigrateDisk.process(['old_disk_cid', 'new_disk_cid'])
    end
  end

  context 'when it fails to remount the old disk' do
    before do
      disk = double('old disk', partition_path: nil)
      platform.stub(:find_disk_by_cid).with('old_disk_cid').and_return(disk)
      disk.stub(:mount).with(@mount_path, '-o ro').and_return(false)
    end

    it 'raises Bosh::Agent::MessageHandlerError' do
      Bosh::Agent::Message::DiskUtil.stub(:umount_guard).with(@mount_path)
      expect {
        Bosh::Agent::Message::MigrateDisk.process(['old_disk_cid', 'new_disk_cid'])
      }.to raise_error(/Failed to mount: .* #{@mount_path}/)
    end
  end

  context 'when it fails to remount the new disk' do
    before do
      disk = double('new disk', partition_path: nil)

      platform.stub(find_disk_by_cid: double('old disk', mount: true, partition_path: nil))
      platform.stub(:find_disk_by_cid).with('new_disk_cid').and_return(disk)

      disk.stub(:mount).with(@mount_path, '').and_return(false)
    end

    it 'raises Bosh::Agent::MessageHandlerError' do
      Bosh::Agent::Message::DiskUtil.stub(:umount_guard)

      expect {
        Bosh::Agent::Message::MigrateDisk.process(['old_disk_cid', 'new_disk_cid'])
      }.to raise_error(/Failed to mount: .* #{@mount_path}/)
    end
  end
end

describe Bosh::Agent::Message::UnmountDisk do
  it 'should unmount disk' do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return("/dev/sdy")
    Bosh::Agent::Message::DiskUtil.stub(:mount_entry).and_return('/dev/sdy1 /foomount fstype')

    handler = Bosh::Agent::Message::UnmountDisk.new
    Bosh::Agent::Message::DiskUtil.stub(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unmounted /dev/sdy1 on /foomount"}
  end

  it "should fall through if mount is not present" do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return("/dev/sdx")
    Bosh::Agent::Message::DiskUtil.stub(:mount_entry).and_return(nil)

    handler = Bosh::Agent::Message::UnmountDisk.new
    handler.stub(:umount_guard)

    handler.unmount(["4"]).should == { :message => "Unknown mount for partition: /dev/sdx1" }
  end
end

describe Bosh::Agent::Message::ListDisk do

  it "should return empty list" do
    settings = { "disks" => { } }
    Bosh::Agent::Config.settings = settings
    Bosh::Agent::Message::ListDisk.process([]).should == []
  end

  it "should list persistent disks" do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return("/dev/sdy")
    Bosh::Agent::Message::DiskUtil.stub(:mount_entry).and_return('/dev/sdy1 /foomount fstype')

    settings = { "disks" => { "persistent" => { 199 => 2 }}}
    Bosh::Agent::Config.settings = settings

    Bosh::Agent::Message::ListDisk.process([]).should == [199]
  end

end

describe Bosh::Agent::Message::DiskUtil do
  describe '#get_usage' do
    it 'should return the disk usage' do
      base = Bosh::Agent::Config.base_dir

      fs_list = [
          double('system', :dir_name => '/'),
          double('ephermal', :dir_name => File.join(base, 'data')),
          double('persistent', :dir_name => File.join(base, 'store'))
      ]

      sigar = double('sigar', :file_system_list => fs_list, :logger= => nil)

      u1 = double('usage', :use_percent => 0.69)
      sigar.should_receive(:file_system_usage).with('/').and_return(u1)

      u2 = double('usage', :use_percent => 0.73)
      sigar.should_receive(:file_system_usage).with(File.join(base, 'data')).and_return(u2)

      u3 = double('usage', :use_percent => 0.11)
      sigar.should_receive(:file_system_usage).with(File.join(base, 'store')).and_return(u3)

      Sigar.stub(:new => sigar)

      described_class.get_usage.should == {
          :system => {:percent => '69'},
          :ephemeral => {:percent => '73'},
          :persistent => {:percent => '11'}
      }
    end

    it 'should not return ephemeral and persistent disks usages if do not exist' do
      base = Bosh::Agent::Config.base_dir

      fs_list = [
          double('system', :dir_name => '/'),
      ]

      sigar = double('sigar', :file_system_list => fs_list, :logger= => nil)

      u1 = double('usage', :use_percent => 0.69)
      sigar.should_receive(:file_system_usage).with('/').and_return(u1)

      sigar.should_not_receive(:file_system_usage).with(File.join(base, 'data'))

      sigar.should_not_receive(:file_system_usage).with(File.join(base, 'store'))

      Sigar.stub(:new => sigar)

      described_class.get_usage.should == {
          :system => {:percent => '69'}
      }
    end
  end
end
