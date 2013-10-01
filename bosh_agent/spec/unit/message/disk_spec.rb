# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Message::MigrateDisk do
  describe '.long_running?' do
    it 'is always true' do
      Bosh::Agent::Message::MigrateDisk.long_running?.should == true
    end
  end

  describe '.process' do
    it 'delegates to #migrate and returns an empty hash' do
      message = double('migrate_disk message')
      described_class.should_receive(:new).with().and_return(message)
      message.should_receive(:migrate).with(["old_disk_cid", "new_disk_cid"])

      described_class.process(["old_disk_cid", "new_disk_cid"]).should eq({})
    end
  end

  describe '#migrate' do
    let(:migration_mount_point) { '/var/vcap/store_migraton_target' } # sic
    let(:persistent_disk_mount_point) { '/var/vcap/store' }
    before do
      store_path = double('store path', mountpoint?: true)
      Pathname.stub(:new).with(persistent_disk_mount_point).and_return(
        store_path
      )

      migration_target_path = double('migration path', mountpoint?: true)
      Pathname.stub(:new).with(migration_mount_point).and_return(
        migration_target_path
      )
    end

    let(:config_class) { double('agent config') }
    before {  stub_const('Bosh::Agent::Config', config_class) }

    subject(:migrate_disk) { described_class.new }
    before do
      fake_logger = double('logger', info: true)
      config_class.stub(logger: fake_logger)
      config_class.stub(base_dir: '/var/vcap')
      platform = double('platform')
      config_class.stub(platform: platform)
      platform.stub(:lookup_disk_by_cid).with("old_disk_cid").and_return(
        '/dev/sda',
      )
      platform.stub(:lookup_disk_by_cid).with("new_disk_cid").and_return(
        '/dev/sdb',
      )

      #config_class.stub(
      #  settings: {
      #    'disks' => {
      #      'ephemeral' => '/dev/sdq',
      #      'persistent' => {
      #        'old_disk_cid' => '/dev/sda',
      #        'new_disk_cid' => '/dev/sdb'
      #      }
      #    }
      #  }
      #)
    end

    it 'remounts the old disk RO, copies files over, and mounts the new disk' do
      # re-mount old disk read-only
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).ordered.with(
          persistent_disk_mount_point,
      )
      mounter_old_disk = double('mounter for old disk')
      Bosh::Agent::Mounter.stub(:new).with(
        anything,
        'old_disk_cid',
        persistent_disk_mount_point,
        anything,
      ).and_return(mounter_old_disk)
      mounter_old_disk.should_receive(:mount).with('-o ro').ordered

      # copy stuff over
      migrate_disk.should_receive(:`).ordered.with(
        "(cd #{persistent_disk_mount_point} && tar cf - .) | (cd #{migration_mount_point} && tar xpf -)"
      )

      # unmount old disk
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).ordered.with(
        persistent_disk_mount_point,
      )

      # re-mount new disk to the right mount point
      Bosh::Agent::Message::DiskUtil.should_receive(:umount_guard).ordered.with(
        migration_mount_point,
      )
      mounter_new_disk = double('mounter for new disk')
      Bosh::Agent::Mounter.stub(:new).with(
        anything,
        'new_disk_cid',
        persistent_disk_mount_point,
        anything,
      ).and_return(mounter_new_disk)
      mounter_new_disk.should_receive(:mount).with('').ordered

      migrate_disk.migrate(["old_disk_cid", "new_disk_cid"])
    end
  end
end

describe Bosh::Agent::Message::UnmountDisk do
  it 'should unmount disk' do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return('/dev/sdy')
    Bosh::Agent::Message::DiskUtil.stub(:mount_entry).and_return('/dev/sdy1 /foomount fstype')

    handler = Bosh::Agent::Message::UnmountDisk.new
    Bosh::Agent::DiskUtil.stub(:umount_guard)

    handler.unmount(['4']).should == {message: 'Unmounted /dev/sdy1 on /foomount'}
  end

  it 'should fall through if mount is not present' do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return('/dev/sdx')
    Bosh::Agent::Message::DiskUtil.stub(:mount_entry).and_return(nil)

    handler = Bosh::Agent::Message::UnmountDisk.new
    handler.stub(:umount_guard)

    handler.unmount(['4']).should == {message: 'Unknown mount for partition: /dev/sdx1'}
  end
end

describe Bosh::Agent::Message::ListDisk do

  it 'should return empty list' do
    settings = { 'disks' => { } }
    Bosh::Agent::Config.settings = settings
    Bosh::Agent::Message::ListDisk.process([]).should == []
  end

  it 'should list persistent disks' do
    platform = double(:platform)
    Bosh::Agent::Config.stub(:platform).and_return(platform)
    platform.stub(:lookup_disk_by_cid).and_return('/dev/sdy')
    Bosh::Agent::Message::DiskUtil.stub(:mount_entry).and_return('/dev/sdy1 /foomount fstype')

    settings = { 'disks' => { 'persistent' => { 199 => 2 }}}
    Bosh::Agent::Config.settings = settings

    Bosh::Agent::Message::ListDisk.process([]).should == [199]
  end

end
