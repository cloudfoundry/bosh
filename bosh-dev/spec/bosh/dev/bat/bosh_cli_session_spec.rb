require 'spec_helper'
require 'bosh/dev/bat/bosh_cli_session'

module Bosh::Dev::Bat
  describe BoshCliSession do
    let(:shell) { instance_double('Bosh::Dev::Shell') }
    let(:tempfile) { instance_double('Tempfile', path: 'fake-tmp/bosh_config') }

    before do
      Bosh::Dev::Shell.stub(:new).and_return(shell)
      subject.stub(:puts)
      Tempfile.stub(:new).with('bosh_config').and_return(tempfile)
    end

    describe '#run_bosh' do
      it 'runs the specified bosh command' do
        shell.should_receive(:run).with("bosh -v -n -P 10 --config 'fake-tmp/bosh_config' fake-cmd", { fake: 'options' })

        subject.run_bosh('fake-cmd', { fake: 'options' })
      end

      context 'when bosh fails and debugging failures' do
        before do
          shell.stub(:run) do |cmd, _|
            raise 'fake-cmd broke' if cmd =~ /fake-cmd/
          end
        end

        it 'debugs the last task' do
          shell.should_receive(:run).with("bosh -v -n -P 10 --config 'fake-tmp/bosh_config' task last --debug", { last_number: 100 })

          expect {
            subject.run_bosh('fake-cmd', debug_on_fail: true)
          }.to raise_error('fake-cmd broke')
        end

        context 'and it also fails debugging the original failure' do
          before do
            shell.stub(:run).and_raise
          end

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
