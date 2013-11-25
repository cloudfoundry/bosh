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
      described_class.should_receive(:new).with(no_args).and_return(message)
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
    before { stub_const('Bosh::Agent::Config', config_class) }

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
    end

    it 'remounts the old disk RO, copies files over, and mounts the new disk' do
      # re-mount old disk read-only
      Bosh::Agent::DiskUtil.should_receive(:umount_guard).ordered.with(
        persistent_disk_mount_point,
      )
      mounter = double('mounter for disks')
      Bosh::Agent::Mounter.stub(:new).with(
        config_class.logger,
      ).and_return(mounter)
      mounter.should_receive(:mount).with('/dev/sda1',
                                          persistent_disk_mount_point,
                                          read_only: true).ordered

      # copy stuff over
      migrate_disk.should_receive(:`).ordered.with(
        "(cd #{persistent_disk_mount_point} && tar cf - .) | (cd #{migration_mount_point} && tar xpf -)"
      )

      # unmount old disk
      Bosh::Agent::DiskUtil.should_receive(:umount_guard).ordered.with(
        persistent_disk_mount_point,
      )

      # re-mount new disk to the right mount point
      Bosh::Agent::DiskUtil.should_receive(:umount_guard).ordered.with(
        migration_mount_point,
      )
      mounter.should_receive(:mount).with('/dev/sdb1',
                                          persistent_disk_mount_point, {}).ordered

      migrate_disk.migrate(["old_disk_cid", "new_disk_cid"])
    end
  end
end
