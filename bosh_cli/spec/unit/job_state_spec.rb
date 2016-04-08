require 'spec_helper'

module Bosh::Cli
  describe JobState do
    include FakeFS::SpecHelpers

    let(:director) { instance_double(Client::Director) }
    let(:command) { instance_double(Command::Base) }
    let(:force) { false }

    let(:manifest) { Manifest.new('fake-deployment-file', director) }

    before do
      manifest_hash = {'name' => 'fake deployment', 'inspected' => false}
      File.open('fake-deployment-file', 'w') { |f| f.write(manifest_hash.to_yaml) }
      manifest.load

      allow(command).to receive(:err) { |message| raise Bosh::Cli::CliError, message }
      allow(command).to receive(:cancel_deployment) { raise Bosh::Cli::GracefulExit  }
      allow(command).to receive(:director) { director }
      allow(command).to receive(:say)
      allow(command).to receive(:nl)
      allow(director).to receive(:change_job_state)
    end

    subject(:job_state) do
      JobState.new(command, manifest, force)
    end

    describe '#change' do
      it 'blows up if there are manifest changes' do
        allow(command).to receive(:inspect_deployment_changes).with(manifest, hash_including(show_empty_changeset: false)) do |manifest, _|
          true
        end

        expect {
          job_state.change(:start, 'fake job', 'fake index', force)
        }.to raise_error(Bosh::Cli::CliError, "Cannot perform job management when other deployment changes are present. Please use '--force' to override.")

        expect(director).to_not have_received(:change_job_state)
      end

      it 'cancels the deploy if the user doesnt confirm' do
        allow(command).to receive(:inspect_deployment_changes).with(manifest, hash_including(show_empty_changeset: false)) do |manifest, _|
          false
        end
        allow(command).to receive_messages(confirmed?: false)

        expect {
          job_state.change(:start, 'fake job', 'fake index', force)
        }.to raise_error(Bosh::Cli::GracefulExit)

        expect(director).to_not have_received(:change_job_state)
      end

      it 'changes the job state when the user confirms (or its non-interactive) and there arent any manifest changes' do
        allow(command).to receive(:inspect_deployment_changes).with(manifest, hash_including(show_empty_changeset: false)) do |manifest, _|
          false
        end
        allow(command).to receive(:confirmed?) { true }

        job_state.change(:start, 'fake job', 'fake index', force)

        expect(director).to have_received(:change_job_state).
            with('fake deployment', Psych.dump(manifest.hash), 'fake job', 'fake index', 'started', false)
      end

      context 'when run forcefully' do
        let(:force) { true }
        it 'does not blow up when changes are present' do
          allow(command).to receive(:inspect_deployment_changes).with(manifest, hash_including(show_empty_changeset: false)) do |manifest, _|
            true
          end
          allow(command).to receive_messages(confirmed?: true)

          job_state.change(:start,'fake job', 'fake index', force)

          expect(command).to_not have_received(:err).with("Cannot perform job management when other deployment changes are present. Please use '--force' to override.")
          expect(director).to have_received(:change_job_state).
              with('fake deployment', Psych.dump(manifest.hash), 'fake job', 'fake index', 'started', force)
        end
      end
    end
  end
end
