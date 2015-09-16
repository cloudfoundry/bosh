require 'spec_helper'
require 'bosh/dev/deployments_repository'

module Bosh::Dev
  describe DeploymentsRepository do
    include FakeFS::SpecHelpers

    subject { described_class.new(env, logger, options) }
    let(:env) { { 'BOSH_JENKINS_DEPLOYMENTS_REPO' => 'fake_BOSH_JENKINS_DEPLOYMENTS_REPO' } }
    let(:options) { {} }

    before { allow(Bosh::Core::Shell).to receive_messages(new: shell) }
    let(:shell) { instance_double('Bosh::Core::Shell', run: 'FAKE_SHELL_OUTPUT') }

    let(:git_repo_updater) { instance_double('Bosh::Dev::GitRepoUpdater') }
    before { allow(Bosh::Dev::GitRepoUpdater).to receive(:new).with(logger).and_return(git_repo_updater) }

    describe '#path' do
      its(:path) { should eq('/tmp/deployments') }

      context 'when "WORKSPACE" is set' do
        before do
          env.merge!(
            'BOSH_JENKINS_DEPLOYMENTS_REPO' => 'fake_BOSH_JENKINS_DEPLOYMENTS_REPO',
            'WORKSPACE' => '/my/private/idaho'
          )
        end

        its(:path) { should eq('/my/private/idaho/deployments') }
      end

      context 'when path is passed into initialize' do
        before { options[:path_root] = '/some/fake/path' }

        its(:path) { should eq('/some/fake/path/deployments') }
      end
    end

    describe '#clone_or_update!' do
      context 'when the directory does exist' do
        before { FileUtils.mkdir_p(subject.path) }

        context 'when the directory contains a .git subdirectory' do
          before { FileUtils.mkdir_p(File.join(subject.path, '.git')) }

          it 'updates the repo at "#path"' do
            expect(shell).to receive(:run).with('git clean -fd && git pull', output_command: true)
            subject.clone_or_update!
          end
        end

        context 'when the directory does not contain a .git subdirectory' do
          it 'clones the repo into "#path"'do
            expect(shell).to receive(:run).with('git clone --depth=1 fake_BOSH_JENKINS_DEPLOYMENTS_REPO /tmp/deployments', output_command: true)
            subject.clone_or_update!
          end
        end
      end

      context 'when the directory does NOT exist' do
        it 'clones the repo into "#path"'do
          expect(shell).to receive(:run).with('git clone --depth=1 fake_BOSH_JENKINS_DEPLOYMENTS_REPO /tmp/deployments', output_command: true)

          expect {
            subject.clone_or_update!
          }.to change { Dir.exists?(subject.path) }.from(false).to(true)
        end
      end
    end

    describe '#push' do
      it 'commit and pushes the current state of the directory' do
        expect(git_repo_updater).to receive(:update_directory).with('/tmp/deployments', kind_of(String))
        subject.push
      end
    end

    describe '#update_and_push' do
      before { allow(Bosh::Dev::GitRepoUpdater).to receive(:new).and_return(git_repo_updater) }
      let(:git_repo_updater) { instance_double('Bosh::Dev::GitRepoUpdater') }

      before { FileUtils.mkdir_p(subject.path) }

      it 'updates repo by pulling in new changes, commits and pushes the current state of the directory' do
        expect(shell).to receive(:run).with('git clean -fd && git pull', output_command: true).ordered
        expect(git_repo_updater).to receive(:update_directory).with('/tmp/deployments', kind_of(String)).ordered
        subject.update_and_push
      end

      it 'does not commit and push if pulling in new changes fails due to merge conflicts' do
        error = Exception.new('fake-pull-exception')
        expect(shell).to receive(:run).with('git clean -fd && git pull', output_command: true).and_raise(error)
        expect(git_repo_updater).not_to receive(:update_directory)

        expect {
          subject.update_and_push
        }.to raise_error(error)
      end

      context 'when fails to push because of non-fast-forward' do
        before do
          allow(git_repo_updater).to receive(:update_directory).and_raise(GitRepoUpdater::PushRejectedError)
        end

        it 'updates and retries 3 times' do
          expect(git_repo_updater).to receive(:update_directory).exactly(3).times

          expect {
            subject.update_and_push
          }.to raise_error GitRepoUpdater::PushRejectedError
        end
      end
    end
  end
end
