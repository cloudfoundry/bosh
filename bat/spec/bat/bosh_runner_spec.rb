require 'spec_helper'
require 'bat/bosh_runner'
require 'logger'

describe Bat::BoshRunner do
  describe '#bosh' do
    subject { described_class.new('fake-bosh-exe', 'fake-path-to-bosh-config', logger) }
    let(:logger) { instance_double('Logger', info: nil) }

    let(:bosh_exec) { class_double('Bosh::Exec').as_stubbed_const(transfer_nested_constants: true) }
    let(:bosh_exec_result) { instance_double('Bosh::Exec::Result', output: 'FAKE_OUTPUT') }

    it 'uses Bosh::Exec to shell out to bosh' do
      expected_command = %W(
        fake-bosh-exe
        --non-interactive
        -P 1
        --config fake-path-to-bosh-config
        --user admin --password admin
        FAKE_ARGS 2>&1
      ).join(' ')

      logger.should_receive(:info).with("Running bosh command --> #{expected_command}")
      bosh_exec.should_receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)

      subject.bosh('FAKE_ARGS')
    end

    it 'returns the result of Bosh::Exec' do
      bosh_exec.stub(sh: bosh_exec_result)

      expect(subject.bosh('FAKE_ARGS')).to eq(bosh_exec_result)
    end

    context 'when options are passed' do
      it 'passes the options to Bosh::Exec' do
        bosh_exec.should_receive(:sh).with(anything, { foo: :bar }).and_return(bosh_exec_result)

        subject.bosh('FAKE_ARGS', { foo: :bar })
      end
    end

    context 'when bosh command raises an error' do
      it 'prints Bosh::Exec::Error messages and re-raises' do
        bosh_exec.stub(:sh).and_raise(Bosh::Exec::Error.new(1, 'fake command', 'fake output'))

        expect {
          subject.bosh('FAKE_ARG')
        }.to raise_error(Bosh::Exec::Error, /fake command/)
      end
    end

    it 'prints the output from the Bosh::Exec result' do
      bosh_exec.stub(:sh).and_return(bosh_exec_result)

      logger.should_receive(:info).with('FAKE_OUTPUT')

      subject.bosh('fake arg')
    end

    context 'when a block is passed' do
      it 'yields the Bosh::Exec result' do
        bosh_exec.stub(sh: bosh_exec_result)

        expect { |b|
          subject.bosh('fake arg', &b)
        }.to yield_with_args(bosh_exec_result)
      end
    end
  end
end
