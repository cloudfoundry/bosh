# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Message::MigrateDisk do
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

    Dir.stub(:glob).with(['/dev/sda', '/dev/vda', '/dev/xvda']).and_return(['/dev/sda'])
    Dir.stub(:glob).with(['/dev/sdb', '/dev/vdb', '/dev/xvdb']).and_return(['/dev/sdb'])

    @mount_path = File.join(Bosh::Agent::Config.base_dir, 'store')
    @migration_mount_path = File.join(Bosh::Agent::Config.base_dir, 'store_migraton_target') # (sic)

    mountpoint = double('mountpoint', mountpoint?: true)
    Pathname.stub(:new).with(@mount_path).and_return(mountpoint)
    Pathname.stub(:new).with(@migration_mount_path).and_return(mountpoint)

    @original_backtick = Kernel.instance_method(:`)
    bi = @backtick_invocations = []
    stubbed_backtick = proc do |cmd|
      bi << cmd
    end
    Kernel.define_method(:`, &stubbed_backtick)
  end

  after do
    Kernel.define_method(:`, @original_backtick)
    @backtick_invocations.clear
  end

  it 'should migrate to the new persistent disk' do
    message = Bosh::Agent::Message::MigrateDisk.new
    Bosh::Agent::Message::MigrateDisk.stub(:new).and_return(message)
    utils = Bosh::Agent::Message::DiskUtil

    Bosh::Agent::Message::MigrateDisk.process(['old_disk_cid', 'new_disk_cid'])
    @backtick_invocations.should eq(
                                   [
                                     # Remount old disk as read-only
                                     "umount #{@mount_path} 2>&1",
                                     "mount -o ro /dev/sda1 #{@mount_path}",
                                     # Copy data from old disk to new disk
                                     "(cd #{@mount_path} && tar cf - .) | (cd #{@migration_mount_path} && tar xpf -)",
                                     # Unmount all disks
                                     "umount #{@mount_path} 2>&1",
                                     "umount #{@migration_mount_path} 2>&1",
                                     # Remount new disk
                                     "mount  /dev/sdb1 #{@mount_path}",
                                   ]
                                 )
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
