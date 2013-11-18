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
      its(:path) { should eq('/mnt/deployments') }

      context 'when "FAKE_MNT" is set' do
        before do
          env.merge!(
            'BOSH_JENKINS_DEPLOYMENTS_REPO' => 'fake_BOSH_JENKINS_DEPLOYMENTS_REPO',
            'FAKE_MNT' => '/my/private/idaho'
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
            shell.should_receive(:run).with('git clone fake_BOSH_JENKINS_DEPLOYMENTS_REPO /mnt/deployments')

            subject.clone_or_update!
          end
        end
      end

      context 'when the directory does NOT exist' do
        it 'clones the repo into "#path"'do
          shell.should_receive(:run).with('git clone fake_BOSH_JENKINS_DEPLOYMENTS_REPO /mnt/deployments')

          expect {
            subject.clone_or_update!
          }.to change { Dir.exists?(subject.path) }.from(false).to(true)
        end
      end
    end

    describe '#push' do
      let(:git_repo_updater) { instance_double('Bosh::Dev::GitRepoUpdater') }

      it 'commit and pushes the current state of the directory' do
        Bosh::Dev::GitRepoUpdater.stub(:new) { git_repo_updater }
        git_repo_updater.should_receive(:update_directory).with('/mnt/deployments')

        subject.push
      end
    end
  end
end
