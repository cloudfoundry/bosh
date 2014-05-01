require 'spec_helper'
require 'bosh/dev/deployments_repository'

module Bosh::Dev
  describe DeploymentsRepository do
    include FakeFS::SpecHelpers

    subject { described_class.new(env, options) }
    let(:env) { { 'BOSH_JENKINS_DEPLOYMENTS_REPO' => 'fake_BOSH_JENKINS_DEPLOYMENTS_REPO' } }
    let(:options) { {} }

    before { Bosh::Core::Shell.stub(new: shell) }
    let(:shell) { instance_double('Bosh::Core::Shell', run: 'FAKE_SHELL_OUTPUT') }

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
            shell.should_receive(:run).with('git pull')
            subject.clone_or_update!
          end
        end

        context 'when the directory does not contain a .git subdirectory' do
          it 'clones the repo into "#path"'do
            shell.should_receive(:run).with('git clone fake_BOSH_JENKINS_DEPLOYMENTS_REPO /tmp/deployments')
            subject.clone_or_update!
          end
        end
      end

      context 'when the directory does NOT exist' do
        it 'clones the repo into "#path"'do
          shell.should_receive(:run).with('git clone fake_BOSH_JENKINS_DEPLOYMENTS_REPO /tmp/deployments')

          expect {
            subject.clone_or_update!
          }.to change { Dir.exists?(subject.path) }.from(false).to(true)
        end
      end
    end

    describe '#push' do
      before { Bosh::Dev::GitRepoUpdater.stub(:new).and_return(git_repo_updater) }
      let(:git_repo_updater) { instance_double('Bosh::Dev::GitRepoUpdater') }

      it 'commit and pushes the current state of the directory' do
        git_repo_updater.should_receive(:update_directory).with('/tmp/deployments')
        subject.push
      end
    end

    describe '#update_and_push' do
      before { Bosh::Dev::GitRepoUpdater.stub(:new).and_return(git_repo_updater) }
      let(:git_repo_updater) { instance_double('Bosh::Dev::GitRepoUpdater') }

      before { FileUtils.mkdir_p(subject.path) }

      it 'updates repo by pulling in new changes, commits and pushes the current state of the directory' do
        shell.should_receive(:run).with('git pull').ordered
        git_repo_updater.should_receive(:update_directory).with('/tmp/deployments').ordered
        subject.update_and_push
      end

      it 'does not commit and push if pulling in new changes fails due to merge conflicts' do
        error = Exception.new('fake-pull-exception')
        shell.should_receive(:run).with('git pull').and_raise(error)
        git_repo_updater.should_not_receive(:update_directory)

        expect {
          subject.update_and_push
        }.to raise_error(error)
      end
    end
  end
end
