require 'spec_helper'

require 'bosh/dev/shipit_lifecycle'

module Bosh::Dev
  describe ShipitLifecycle do
    let(:repo_path) { '/home/user/bosh' }
    let(:head_reference) { double('Rugged::Reference', name: 'refs/heads/this-branch') }
    let(:repository) { double('Rugged::Repository', head: head_reference) }
    let(:shell) { double('Bosh::Dev::Shell') }

    before do
      Bosh::Dev::Shell.stub(:new).and_return(shell)
      Rugged::Repository.stub(:discover).with('.').and_return(repo_path)
      Rugged::Repository.stub(:new).with(repo_path).and_return(repository)
    end

    describe '.pull' do
      it 'pulls the current branch from origin' do
        shell.should_receive(:run).with('git pull --rebase origin this-branch')
        ShipitLifecycle.new.pull
      end
    end

    describe '.push' do
      it 'pushes the current branch to origin' do
        shell.should_receive(:run).with('git push origin this-branch')
        ShipitLifecycle.new.push
      end
    end
  end
end