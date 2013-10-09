require 'spec_helper'
require 'bosh_agent/mounter'

describe Bosh::Agent::Mounter do
  describe '#mount' do
    subject(:mounter) { described_class.new(logger, shell_runner) }
    let(:logger) { double('logger') }
    let(:shell_runner) { double() }
    let(:options) { {} }
    let(:result) { instance_double('Bosh::Exec::Result', exit_status: 0, output: 'mount-output', failed?: false) }

    def perform
      mounter.mount('/dev/sda1', '/path/to/mount/point', options)
    end

    context 'when mount succeeds' do
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

    context 'when mount called with options' do
      before { logger.stub(:info) }

      context 'valid options' do
        let(:options) { { read_only: true } }

        it 'sets proper command line options' do
          shell_runner.should_receive(:sh).with('mount -o ro /dev/sda1 /path/to/mount/point', on_error: :return).and_return(result)
          perform
        end
      end

      context 'invalid options' do
        let(:options) { { invalid_option: true } }

        it 'raises' do
          expect { perform }.to raise_error(
            Bosh::Agent::Error,
            "Invalid options: {:invalid_option=>true}",
          )
        end
      end
    end
  end
end
