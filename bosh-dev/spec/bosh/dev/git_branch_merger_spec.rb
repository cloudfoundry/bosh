require 'spec_helper'
require 'logger'
require 'bosh/dev/git_branch_merger'
require 'bosh/core/shell'

module Bosh::Dev
  describe GitBranchMerger do
    describe '#merge' do
      let(:target_branch) { 'targetted-branch' }
      let(:commit_message) { 'Merging stuff!' }
      let(:git_branch_merger) { described_class.new }
      let(:shell) { instance_double('Bosh::Core::Shell') }

      before { Bosh::Core::Shell.stub(new: shell) }

      it 'fetches the targetted branch, merges with the correct messages and pushes the merge back to the targetted branch' do
        expect(shell).to receive(:run).with('git fetch origin develop').ordered
        expect(shell).to receive(:run).with("git merge origin/develop -m '#{commit_message}'")
        expect(shell).to receive(:run).with('git push origin HEAD:develop').ordered

        git_branch_merger.merge(target_branch, commit_message)
      end
    end
  end
end
