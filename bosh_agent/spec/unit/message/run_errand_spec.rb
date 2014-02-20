require "spec_helper"

describe Bosh::Agent::Message::RunErrand do
  subject(:run_errand) { described_class.new([]) }

  before { allow(Bosh::Agent::Config).to receive(:base_dir).and_return('fake-base-dir') }

  before { allow(Bosh::Agent::Config).to receive(:state).and_return(bosh_agent_config_state) }
  let(:bosh_agent_config_state) { { 'job' => { 'templates' => [{ 'name' => 'fake-job-name'}] } } }

  before { allow(Open3).to receive(:capture3) }

  context 'when the first job template is runnable' do
    before { allow(File).to receive(:executable?).with(match(%r{bin/run})).and_return(true) }

    context 'when executing run errand does not raise any error' do
      it 'runs the job and returns its output and exit code' do
        expected_env = { 'PATH' => '/usr/sbin:/usr/bin:/sbin:/bin' }
        expected_cmd = 'fake-base-dir/jobs/fake-job-name/bin/run'
        expected_opts = { :unsetenv_others => true }

        exit_status = instance_double('Process::Status')
        allow(exit_status).to receive(:exitstatus).and_return(123)

        expect(Open3).to receive(:capture3).
          with(expected_env, expected_cmd, expected_opts).
          and_return(['fake-stdout', 'fake-stderr', exit_status])

        expect(run_errand.start).to eq(
          'exit_code' => 123,
          'stdout' => 'fake-stdout',
          'stderr' => 'fake-stderr',
        )
      end
    end

    context 'when executing run errand raises an error' do
      it 'raises MessageHandlerError' do
        error = Exception.new('fake-error')
        allow(Open3).to receive(:capture3).and_raise(error)
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
end
