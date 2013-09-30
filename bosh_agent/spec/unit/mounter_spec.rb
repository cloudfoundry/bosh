require 'spec_helper'
require 'bosh_agent/mounter'

describe Bosh::Agent::Mounter do
  describe '#mount' do
    subject(:mounter) do
      described_class.new(
        platform,
        disk_cid,
        mount_point,
        logger,
        backticker,
      )
    end
    let(:platform) { double('platform') }
    let(:disk_cid) { 'disk_cid' }
    let(:mount_point) { '/path/to/mount/point' }
    let(:logger) { double('logger') }
    let(:backticker) { double('backticker') }

    context 'when command to mount succeeds' do
      it 'looks up the disk device path, logs, and mounts the partition onto path' do
        platform.should_receive(:lookup_disk_by_cid).with(disk_cid).and_return(
          '/dev/sda',
        )
        logger.should_receive(:info).with(
          "Mounting: /dev/sda1 #{mount_point}"
        )
        backticker.should_receive(:`).with(
          "mount  /dev/sda1 #{mount_point}"
        )

        mounter.mount('')
      end
    end

    context 'when shell command to mount fails' do
      it 'raises' do
        platform.should_receive(:lookup_disk_by_cid).with(disk_cid).and_return(
          '/dev/sda',
        )
        logger.should_receive(:info).with(
          "Mounting: /dev/sda1 #{mount_point}"
        )
        backticker.should_receive(:`).with(
          "mount  /dev/sda1 #{mount_point}"
        ) { system("false") }

        expect {
          mounter.mount('')
        }.to raise_error(/Failed to mount:/)
      end
    end
  end
end
