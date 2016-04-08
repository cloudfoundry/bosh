require 'spec_helper'
require 'bosh/dev/git_branch_merger'
require 'bosh/core/shell'

module Bosh::Dev
  describe GitBranchMerger do
    let(:git_branch_merger) { described_class.new('fake-dir', logger) }

    describe '#merge' do
      let(:source_sha) { 'fake-source-sha' }
      let(:target_branch) { 'fake-target-branch' }
      let(:commit_message) { 'Merging stuff!' }
      let(:shell) { instance_double('Bosh::Core::Shell') }

      it 'fetches the targetted branch, merges with the correct messages and pushes the merge back to the targetted branch' do
        expect(Open3).to receive(:capture3).with("git fetch origin #{target_branch}", chdir: 'fake-dir').
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ]).ordered

        expect(Open3).to receive(:capture3).with("git checkout #{target_branch}", chdir: 'fake-dir').
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ]).ordered

        expect(Open3).to receive(:capture3).with("git merge #{source_sha} -m '#{commit_message}'", chdir: 'fake-dir').
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ]).ordered

        expect(Open3).to receive(:capture3).with("git push origin #{target_branch}", chdir: 'fake-dir').
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ]).ordered

        git_branch_merger.merge(source_sha, target_branch, commit_message)
      end
    end

    describe '#branch_contains?' do
      let(:branch_name) { 'fake-branch-name' }
      let(:commit_sha) { 'fake-commit-sha' }

      before do
        expect(Open3).to receive(:capture3).with("git fetch origin #{branch_name}", chdir: 'fake-dir').and_return(
          [ '', nil, instance_double('Process::Status', success?: true) ]
        )
      end

      it 'returns true when the given branch contains the given commit sha' do
        expect(Open3).to receive(:capture3).with("git merge-base --is-ancestor #{commit_sha} remotes/origin/#{branch_name}", chdir: 'fake-dir').and_return(
          [ nil, nil, instance_double('Process::Status', success?: true) ]
        )

        expect(git_branch_merger.branch_contains?(branch_name, commit_sha)).to eq(true)
      end

      it 'returns false when the given branch does not contains the given commit sha' do
        expect(Open3).to receive(:capture3).with("git merge-base --is-ancestor #{commit_sha} remotes/origin/#{branch_name}", chdir: 'fake-dir').and_return(
          [ nil, nil, instance_double('Process::Status', success?: false) ]
        )

        expect(git_branch_merger.branch_contains?(branch_name, commit_sha)).to eq(false)
      end
    end
  end
end
