require 'spec_helper'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  describe BoshCliSession do
    let(:shell)    { instance_double('Bosh::Core::Shell') }
    let(:tempfile) { instance_double('Tempfile', path: 'fake-tmp/bosh_config') }

    before do
      Bosh::Core::Shell.stub(:new).and_return(shell)
      subject.stub(:puts)
      Tempfile.stub(:new).with('bosh_config').and_return(tempfile)
    end

    describe '#run_bosh' do
      it 'runs the specified bosh command' do
        expected_cmd = "bosh -v -n -P 10 --config 'fake-tmp/bosh_config' fake-cmd"
        output       = double('cmd-output')
        shell.should_receive(:run).with(expected_cmd, fake: 'options').and_return(output)
        expect(subject.run_bosh('fake-cmd', fake: 'options')).to eq(output)
      end

      context 'when bosh fails with a RuntimeError and retrying' do
        full_cmd = "bosh -v -n -P 10 --config 'fake-tmp/bosh_config' fake-cmd"

        before { retryable.stub(:sleep) }
        let(:retryable) { Bosh::Retryable.new(tries: 2, on: [RuntimeError]) }
        let(:error)     { RuntimeError.new('eror-message') }

        context 'when command finally succeeds on the third time' do
          it 'retries same command given number of times' do
            shell.should_receive(:run).with(full_cmd, {}).ordered.and_raise(error)
            shell.should_receive(:run).with(full_cmd, {}).ordered.and_return('cmd-output')
            expect(subject.run_bosh('fake-cmd', retryable: retryable)).to eq('cmd-output')
          end
        end

        context 'when command still raises an error on the third time' do
          it 'retries and eventually raises an error' do
            shell.should_receive(:run).with(full_cmd, {}).ordered.exactly(2).times.and_raise(error)
            expect {
              subject.run_bosh('fake-cmd', retryable: retryable)
            }.to raise_error(error)
          end
        end
      end

      context 'when bosh fails and debugging failures' do
        before do
          shell.stub(:run) do |cmd, _|
            raise 'fake-cmd broke' if cmd =~ /fake-cmd/
          end
        end

        it 'debugs the last task' do
          expect_cmd = "bosh -v -n -P 10 --config 'fake-tmp/bosh_config' task last --debug"
          shell.should_receive(:run).with(expect_cmd, last_number: 100).and_return('cmd-output')

          expect {
            subject.run_bosh('fake-cmd', debug_on_fail: true)
          }.to raise_error('fake-cmd broke')
        end

        context 'and it also fails debugging the original failure' do
          before { shell.stub(:run).and_raise }

          it "doesn't debug again" do
            shell.should_receive(:run).twice

            expect {
              subject.run_bosh('fake-cmd', debug_on_fail: true)
            }.to raise_error
          end
        end
      end
    end
  end
end
