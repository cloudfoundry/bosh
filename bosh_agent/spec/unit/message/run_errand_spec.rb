require "spec_helper"

describe Bosh::Agent::Message::RunErrand do
  subject(:run_errand) { described_class.new([]) }

  before { allow(Bosh::Agent::Config).to receive(:base_dir).and_return('fake-base-dir') }

  before { allow(Bosh::Agent::Config).to receive(:state).and_return(bosh_agent_config_state) }
  let(:bosh_agent_config_state) { { 'job' => { 'templates' => [{ 'name' => 'fake-job-name'}] } } }

  let(:env) { double(:ENV) }
  before do
    stub_const('ENV', env)
    allow(env).to receive(:[]).with('TMPDIR').and_return('/some/tmp')
  end

  before { allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, wait_thread) }
  let(:stdin) { instance_double('IO', close: nil) }
  let(:stdout) { instance_double('IO', close: nil, read: 'fake-stdout') }
  let(:stderr) { instance_double('IO', close: nil, read: 'fake-stderr') }
  let(:wait_thread) { double(:wait_thread, pid: 'some-pid', value: exit_status) }
  let(:exit_status) { instance_double('Process::Status', exitstatus: 123) }

  context 'when the first job template is runnable' do
    before { allow(File).to receive(:executable?).with(match(%r{bin/run})).and_return(true) }

    context 'when executing run errand does not raise any error' do
      it 'runs the job and returns its output and exit code' do
        expected_env = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin', 'TMPDIR' => '/some/tmp' }
        expected_cmd = 'fake-base-dir/jobs/fake-job-name/bin/run'
        expected_opts = { unsetenv_others: true, pgroup: true }

        expect(Open3).to receive(:popen3).with(expected_env, expected_cmd, expected_opts)
        allow(wait_thread).to receive(:value) do
          expect(described_class.running_errand_pid).to eq('some-pid')
          exit_status
        end

        expect(run_errand.start).to eq(
          'exit_code' => 123,
          'stdout' => 'fake-stdout',
          'stderr' => 'fake-stderr',
        )
        expect(described_class.running_errand_pid).to be_nil
      end

      context 'when the errand is killed' do
        before do
          allow(exit_status).to receive(:exitstatus).and_return(nil)
          allow(exit_status).to receive(:termsig).and_return(15)
        end

        it 'returns the output and an exit code of 128 + signal' do
          expect(run_errand.start).to eq(
            'exit_code' => 143,
            'stdout' => 'fake-stdout',
            'stderr' => 'fake-stderr',
          )
        end
      end
    end

    context 'when executing run errand raises an error' do
      it 'raises MessageHandlerError' do
        error = Exception.new('fake-error')
        allow(Open3).to receive(:popen3).and_raise(error)
        expect {
          run_errand.start
        }.to raise_error(Bosh::Agent::MessageHandlerError, /fake-error/)
      end
    end
  end

  context 'when the first job template is not runnable' do
    before { allow(File).to receive(:executable?).with(match(%r{bin/run})).and_return(false) }

    it 'raises MessageHandlerError' do
      expect {
        run_errand.start
      }.to raise_error(
        Bosh::Agent::MessageHandlerError,
        %r{Job template fake-job-name does not have executable bin/run},
      )
    end
  end

  [{ 'job' => { 'templates' => [] } }, {}].each do |state|
    context 'when there are no job templates' do
      let(:bosh_agent_config_state) { state }

      it 'raises MessageHandlerError' do
        expect {
          run_errand.start
        }.to raise_error(
          Bosh::Agent::MessageHandlerError,
          %r{At least one job template is required to run an errand},
        )
      end
    end
  end

  describe '.cancel' do
    let!(:process) { class_double('Process', kill: 1).as_stubbed_const }

    before do
      allow(described_class).to receive(:sleep)
    end

    context 'when an errand is running' do
      before { described_class.running_errand_pid = 'some-pid' }

      it 'sends a SIGTERM to the errand process' do
        expect(process).to receive(:kill).with(0, 'some-pid').and_return(1)
        expect(process).to receive(:kill).with('-TERM', 'some-pid')
        allow(process).to receive(:kill).with(0, 'some-pid').and_raise(Errno::ESRCH)

        described_class.cancel
      end

      context 'when the errand process does not respond to a SIGTERM' do
        it 'sends a SIGKILL to the errand process' do
          expect(process).to receive(:kill).with('-TERM', 'some-pid')
          expect(process).to receive(:kill).with(0, 'some-pid').
            at_least(Bosh::Agent::Message::RunErrand::CANCEL_GRACE_PERIOD_SECONDS).times
          expect(described_class).to receive(:sleep).with(1).
            exactly(Bosh::Agent::Message::RunErrand::CANCEL_GRACE_PERIOD_SECONDS).times
          expect(process).to receive(:kill).with('-KILL', 'some-pid')

          described_class.cancel
        end

        context 'when the errand process dies before a SIGKILL is sent' do
          before do
            count = 0
            allow(process).to receive(:kill).with(0, 'some-pid') do
              if count == Bosh::Agent::Message::RunErrand::CANCEL_GRACE_PERIOD_SECONDS
                described_class.running_errand_pid = nil
              end
              count += 1
            end
          end

          it 'does not try to kill nil' do
            expect(process).not_to receive(:kill).with('-KILL', nil)

            described_class.cancel
          end
        end
      end

      context 'when the errand dies before a signal is sent' do
        before { allow(process).to receive(:kill).with('-TERM', 'some-pid').and_raise(Errno::ESRCH) }

        it 'does not raise an error' do
          expect { described_class.cancel }.not_to raise_error
        end
      end
    end

    context 'when no errand is running' do
      before do
        described_class.running_errand_pid = nil
        allow(process).to receive(:kill).and_raise(Errno::ESRCH)
      end

      it 'does not raise an error' do
        expect { described_class.cancel }.not_to raise_error
      end
    end
  end
end
