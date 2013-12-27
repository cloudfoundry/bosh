require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/shipit_lifecycle'

module Bosh::Dev
  describe ShipitLifecycle do
    before { Bosh::Core::Shell.stub(:new).and_return(shell) }
    let(:shell) { instance_double('Bosh::Core::Shell') }

    before do
      repo_path = '/home/user/bosh'
      Rugged::Repository.stub(:discover).with('.').and_return(repo_path)
      Rugged::Repository.stub(:new).with(repo_path).and_return(repository)
    end

    let(:repository)     { instance_double('Rugged::Repository', head: head_reference) }
    let(:head_reference) { instance_double('Rugged::Reference', name: 'refs/heads/this-branch') }

    describe '#pull' do
      it 'pulls the current branch from origin' do
        shell.should_receive(:run).with('git pull --rebase origin this-branch', output_command: true)
        subject.pull
      end
    end

    describe '#push' do
      context 'when current branch is not master' do
        before { head_reference.stub(name: 'refs/heads/not-master') }

        it 'pushes the current branch to origin' do
          shell.should_receive(:run).with('git push origin not-master', output_command: true)
          subject.push
        end
      end

      context 'when current branch is master' do
        before { head_reference.stub(name: 'refs/heads/master') }

        it 'does not push to the branch' do
          shell.should_not_receive(:run)
          expect { subject.push }.to raise_error
        end

        it 'raises an error' do
          expect { subject.push }.to raise_error('Will not git push to master branch directly')
        end
      end
    end
  end
end
