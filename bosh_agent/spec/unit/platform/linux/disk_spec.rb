require 'spec_helper'

describe Bosh::Agent::Platform::Linux::Disk do

  subject(:disk_manager) { Bosh::Agent::Platform::Linux::Disk.new }
  let(:store_path) { File.join(Bosh::Agent::Config.base_dir, 'store') }
  let(:dev_path) { '/sys/bus/scsi/devices/2:0:333:0/block/*' }
  let(:mounter) { instance_double('Bosh::Agent::Mounter', mount: nil) }

  let(:configuration) do
    instance_double('Bosh::Agent::Configuration',
                    settings: settings,
                    infrastructure_name: infrastructure_name,
                    platform_name: 'ubuntu',
                    base_dir: '/var/tmp',
                    logger: double('Logger').as_null_object
    )
  end
  before { stub_const('Bosh::Agent::Config', configuration) }
  before { stub_const('Bosh::Agent::Platform::Linux::Disk::DEV_PATH_TIMEOUT', 0) }
  before { stub_const('Bosh::Agent::Platform::Linux::Disk::DISK_RETRY_MAX_DEFAULT', 2) }
  before { Bosh::Agent::Mounter.stub(:new).and_return(mounter) }

  ['vsphere', 'vcloud'].each do |infra|
    context infra do
      let(:settings) { { 'disks' => { 'persistent' => { 2 => '333' } } } }
      let(:infrastructure_name) { infra }

      before { disk_manager.stub(:sh).with('rescan-scsi-bus') }

      it 'looks up disk by cid' do
        Dir.should_receive(:glob).with(dev_path, 0).and_return(['/dev/sdy'])
        disk_manager.lookup_disk_by_cid(2).should eq '/dev/sdy'
      end

      it 'retries disk lookup by cid' do
        Dir.should_receive(:glob).with(dev_path, 0).exactly(2).and_return([])
        expect {
          disk_manager.lookup_disk_by_cid(2)
        }.to raise_error(Bosh::Agent::DiskNotFoundError)
      end

      it 'gets data disk device name' do
        disk_manager.get_data_disk_device_name.should eq '/dev/sdb'
      end

      context 'if persistent disk cid is unknown' do
        let(:settings) { { 'disks' => { 'persistent' => { 199 => 2 } } } }

        it 'raises an exception' do
          expect {
            disk_manager.lookup_disk_by_cid(200)
          }.to raise_error(Bosh::Agent::FatalError, /Unknown persistent disk/)
        end
      end

      context 'when disk is a block device' do
        before do
          Dir.stub(:glob).with(dev_path, 0).and_return(%w(/dev/sdy))
          File.stub(:blockdev?).with('/dev/sdy1').and_return(true)
          File.stub(:read).with('/proc/mounts').and_return('', '/dev/sdy1')
        end

        it 'mounts persistent disk to store_dir if not already mounted' do
          mounter.should_receive(:mount).with('/dev/sdy1', store_path, {})

          disk_manager.mount_persistent_disk(2)
        end

        it 'mounts persistent disk only once' do
          mounter.should_receive(:mount).with('/dev/sdy1', store_path, {}).once

          disk_manager.mount_persistent_disk(2)
          disk_manager.mount_persistent_disk(2)
        end
      end

      context 'when disk is not a block device' do
        it 'does not mount' do
          Dir.stub(:glob).with(dev_path, 0).and_return(%w(/dev/sdy))
          File.stub(:blockdev?).with('/dev/sdy1').and_return(false)

          mounter.should_not_receive(:mount)

          disk_manager.mount_persistent_disk(2)
        end
      end
    end
  end

  context 'AWS' do
    let(:settings) do
      { 'disks' => { 'ephemeral' => '/dev/sdq',
                     'persistent' => { 2 => '/dev/sdf' } } }
    end
    let(:infrastructure_name) { 'aws' }

    it 'gets data disk device name' do
      Dir.should_receive(:glob).with(%w(/dev/sdq /dev/vdq /dev/xvdq)).twice.and_return(%w(/dev/xvdq))
      expect(disk_manager.get_data_disk_device_name).to eq '/dev/xvdq'
    end

    context 'when data disk device name is not present at settings' do
      let(:settings) { { 'disks' => {} } }

      it 'raises an error' do
        expect {
          disk_manager.get_data_disk_device_name
        }.to raise_error(Bosh::Agent::FatalError)
      end
    end

    it 'looks up disk by cid' do
      Dir.should_receive(:glob).with(%w(/dev/sdf /dev/vdf /dev/xvdf)).twice.and_return(%w(/dev/xvdf))
      expect(disk_manager.lookup_disk_by_cid(2)).to eq '/dev/xvdf'
    end
  end

  context 'OpenStack' do
    let(:settings) do
      { 'disks' => { 'ephemeral' => '/dev/sdq',
                     'persistent' => { 2 => '/dev/sdf' } } }
    end
    let(:infrastructure_name) { 'openstack' }

    it 'gets data disk device name' do
      Dir.should_receive(:glob).with(%w(/dev/sdq /dev/vdq /dev/xvdq)).twice.and_return(%w(/dev/vdq))
      expect(disk_manager.get_data_disk_device_name).to eq '/dev/vdq'
    end

    context 'when not present at settings' do
      let(:settings) { { 'disks' => {} } }
      it 'does not get data disk device name' do
        expect(disk_manager.get_data_disk_device_name).to be_nil
      end
    end

    it 'looks up disk by cid' do
      Dir.should_receive(:glob).with(%w(/dev/sdf /dev/vdf /dev/xvdf)).twice.and_return(%w(/dev/vdf))
      expect(disk_manager.lookup_disk_by_cid(2)).to eq '/dev/vdf'
    end
  end
end
