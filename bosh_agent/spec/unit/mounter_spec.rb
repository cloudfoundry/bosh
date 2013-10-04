require 'spec_helper'
require 'bosh_agent/mounter'

describe Bosh::Agent::Mounter do
  describe '#mount' do
    subject(:mounter) { described_class.new(logger, shell_runner) }
    let(:logger) { double('logger') }
    let(:shell_runner) { double() }

    def perform
      mounter.mount('/dev/sda1', '/path/to/mount/point', '')
    end

    context 'when mount succeeds' do
      let(:result) { instance_double('Bosh::Exec::Result', exit_status: 0, output: 'mount-output', failed?: false) }

      it 'runs mount command with looked up disk' do
        logger.should_receive(:info).with('Mounting: /dev/sda1 /path/to/mount/point')
        shell_runner.should_receive(:sh).with('mount  /dev/sda1 /path/to/mount/point', on_error: :return).and_return(result)
        perform
      end
    end

    context 'when mount fails' do
      let(:result) { instance_double('Bosh::Exec::Result', exit_status: 127, output: 'mount-output', failed?: true) }

      it 'raises' do
        logger.should_receive(:info).with('Mounting: /dev/sda1 /path/to/mount/point')
        shell_runner.should_receive(:sh).with('mount  /dev/sda1 /path/to/mount/point', on_error: :return).and_return(result)

        expect { perform }.to raise_error(
          Bosh::Agent::MessageHandlerError,
          "Failed to mount: '/dev/sda1' '/path/to/mount/point' Exit status: 127 Output: mount-output",
        )
      end
    end
  end
end
