require 'spec_helper'

module Bosh::Agent
  module Message
    describe MountDisk do
      include FakeFS::SpecHelpers

      describe '#mount' do
        subject(:mount_disk_handler) { MountDisk.new(%w(disk-cid)) }

        before { stub_const('Bosh::Agent::Config', configuration) }
        let(:configuration) do
          instance_double('Bosh::Agent::Configuration',
                          configure: true,
                          :settings= => nil,
                          settings: double('Settings', inspect: nil, :[] => 'disk'),
                          logger: logger,
                          platform: platform,
                          base_dir: '/var/vcap',
          )
        end
        let(:mounter) { instance_double('Bosh::Agent::Mounter', mount: nil) }

        let(:logger) { instance_double('Logger', info: nil) }
        let(:platform) { instance_double('Bosh::Agent::Platform::Linux::Adapter', lookup_disk_by_cid: '/dev/sda') }

        before { stub_const('Bosh::Agent::DiskUtil', disk_util) }
        let(:disk_util) { class_double('Bosh::Agent::DiskUtil') }

        before do
          Settings.stub(:load)
          Bosh::Agent::Mounter.stub(:new).with(logger).and_return(mounter)

          mount_disk_handler.stub(:`)
          mount_disk_handler.stub(:sleep)

          disk_util.stub(ensure_no_partition?: false)

          FileUtils.mkdir('/dev')
          File.open('/dev/sda', 'w+') { |f| f.write("\x00"*512) }
          File.stub(:blockdev?).with('/dev/sda').and_return(true)
          File.stub(:blockdev?).with('/dev/sda1').and_return(true)
        end

        context 'disk is not found' do
          before do
            File.stub(:blockdev?).with('/dev/sda').and_return(false)
            File.stub(:blockdev?).with('/dev/sda1').and_return(false)
          end

          it 'raises' do
            expect {
              mount_disk_handler.mount
            }.to raise_error(MessageHandlerError, 'Unable to format /dev/sda')
          end
        end

        context 'partition is found on the disk' do

          it 'does not partition the disk' do
            Bosh::Agent::Util.should_not_receive(:partition_disk)
            mount_disk_handler.mount
          end
        end

        context 'partition is not found on the disk' do
          before do
            disk_util.stub(ensure_no_partition?: true)
            File.stub(:blockdev?).with('/dev/sda1').and_return(false)
          end

          it 'partitions the disk' do
            Bosh::Agent::Util.should_receive(:partition_disk).with('/dev/sda', ",,L\n")
            mount_disk_handler.mount
          end

          it 'formats the partition' do
            Bosh::Agent::Util.stub(:partition_disk)
            Bosh::Agent::Util.stub(lazy_itable_init_enabled?: true)

            mount_disk_handler.should_receive(:`).with('/sbin/mke2fs -t ext4 -j -E lazy_itable_init=1 /dev/sda1')

            mount_disk_handler.mount
          end
        end

        context 'not mount a disk for migration' do
          it 'mounts to /var/vcap/store' do
            mounter.should_receive(:mount).with('/dev/sda1', '/var/vcap/store')
            mount_disk_handler.mount

            expect(File.directory?('/var/vcap/store')).to be(true)
          end
        end

        context 'fails to mount a disk' do
          it 'passes through error from Mounter' do
            mounter.stub(:mount).and_raise(Bosh::Agent::MessageHandlerError,
                                           "Failed to mount: '/dev/sda1' '/var/vcap/store' Exit status: 1 Output: FAIL")
            mounter.should_receive(:mount).with('/dev/sda1', '/var/vcap/store')
            expect {
              mount_disk_handler.mount
            }.to raise_error(Bosh::Agent::MessageHandlerError,
                             "Failed to mount: '/dev/sda1' '/var/vcap/store' Exit status: 1 Output: FAIL")
          end
        end
      end
    end
  end
end
