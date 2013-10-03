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
      )
    end

    let(:platform) { double('platform') }
    let(:disk_cid) { 'disk_cid' }
    let(:mount_point) { '/path/to/mount/point' }
    let(:logger) { double('logger') }

    before { mounter.stub(:`) }

    context 'when mount succeeds' do
      before { mounter.stub(last_process_status: process_status) }
      let(:process_status) { instance_double('Process::Status', exitstatus: 0) }

      it 'runs mount command with looked up disk' do
        platform.should_receive(:lookup_disk_by_cid).with(disk_cid).and_return('/dev/sda')
        logger.should_receive(:info).with("Mounting: /dev/sda1 #{mount_point}")
        mounter.should_receive(:`).with("mount  /dev/sda1 #{mount_point}")
        mounter.mount('')
      end
    end

    context 'when mount fails' do
      before { mounter.stub(last_process_status: process_status) }
      let(:process_status) { instance_double('Process::Status', exitstatus: 127) }

      it 'raises' do
        platform.should_receive(:lookup_disk_by_cid).with(disk_cid).and_return('/dev/sda')
        logger.should_receive(:info).with("Mounting: /dev/sda1 #{mount_point}")
        mounter.should_receive(:`).with("mount  /dev/sda1 #{mount_point}").and_return('mount-output')

        expect {
          mounter.mount('')
        }.to raise_error(Bosh::Agent::MessageHandlerError, /Failed to mount.*127.*mount-output/)
      end
    end
  end
end
