require 'spec_helper'
require 'logger'
require 'bosh/dev/git_branch_merger'
require 'bosh/core/shell'

module Bosh::Dev
  describe GitBranchMerger do
    let(:git_branch_merger) { described_class.new(logger) }
    let(:logger) { Logger.new('/dev/null') }

    describe '#merge' do
      let(:target_branch) { 'fake-target-branch' }
      let(:commit_message) { 'Merging stuff!' }
      let(:shell) { instance_double('Bosh::Core::Shell') }

      before { allow(Bosh::Core::Shell).to receive(:new).and_return(shell) }

      it 'fetches the targetted branch, merges with the correct messages and pushes the merge back to the targetted branch' do
        expect(Open3).to receive(:capture3).with("git fetch origin #{target_branch}").
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ]).ordered

        expect(Open3).to receive(:capture3).with("git merge origin/#{target_branch} -m '#{commit_message}'").
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ]).ordered

        expect(Open3).to receive(:capture3).with("git push origin HEAD:#{target_branch}").
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ]).ordered

        git_branch_merger.merge(target_branch, commit_message)
      end
    end

    describe '#branch_contains?' do
      let(:branch_name) { 'fake-branch-name' }
      let(:commit_sha) { 'fake-commit-sha' }

      before do
        allow(Open3).to receive(:capture3).with("git fetch origin #{branch_name}").and_return(
          [ '', nil, instance_double('Process::Status', success?: true) ]
        )
      end

      it 'returns true when the given branch contains the given commit sha' do
        expect(Open3).to receive(:capture3).with("'git branch --contains #{commit_sha}").and_return(
          [ "a-fake-branch\n#{branch_name}", nil, instance_double('Process::Status', success?: true) ]
        )

        expect(git_branch_merger.branch_contains?(branch_name, commit_sha)).to eq(true)
      end

      it 'returns false when the given branch does not contains the given commit sha' do
        expect(Open3).to receive(:capture3).with("'git branch --contains #{commit_sha}").and_return(
          [ "not-#{branch_name}\nblah", nil, instance_double('Process::Status', success?: true) ]
        )

        expect(git_branch_merger.branch_contains?(branch_name, commit_sha)).to eq(false)
      end
    end
  end
end
