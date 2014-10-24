require 'spec_helper'
require 'bosh/dev/git_repo_updater'
require 'logger'

module Bosh::Dev
  describe GitRepoUpdater do
    include FakeFS::SpecHelpers

    subject(:git_repo_updater) { described_class.new(logger) }
    let(:logger) { Logger.new('/dev/null') }

    let(:dir) { '/some/dir' }

    before do
      allow(Open3).to receive(:capture3).
          and_return([ '', nil, instance_double('Process::Status', success?: true) ])

      FileUtils.mkdir_p(dir)
    end

    it 'changes to the directory' do
      expect(Dir).to receive(:chdir).with(dir)

      subject.update_directory(dir)
    end

    it 'adds untracked files' do
      expect(Open3).to receive(:capture3).with('git add .').
          and_return([ '', nil, instance_double('Process::Status', success?: true) ])

      subject.update_directory(dir)
    end

    it 'adds modified files' do
      expect(Open3).to receive(:capture3).with("git commit -a -m 'Autodeployer receipt file update'").
          and_return([ '', nil, instance_double('Process::Status', success?: true) ])

      subject.update_directory(dir)
    end

    it 'git pushes' do
      expect(Open3).to receive(:capture3).with('git push').
          and_return([ '', nil, instance_double('Process::Status', success?: true) ])

      subject.update_directory(dir)
    end

    context 'when there are no modified files to commit' do
      before do
        allow(Open3).to receive(:capture3).with('git status').
          and_return([ no_modified_files_message, nil, instance_double('Process::Status', success?: true) ])
      end

      context 'when the message has parantheses' do
        let(:no_modified_files_message) { 'nothing to commit (working directory clean)' }

        it 'does not commit' do
          expect(Open3).to_not receive(:capture3).with("git commit -a -m 'Autodeployer receipt file update'")

          subject.update_directory(dir)
        end

        it 'does not push' do
          expect(Open3).to_not receive(:capture3).with('git push')

          subject.update_directory(dir)
        end
      end

      context 'when the message has a comma' do
        let(:no_modified_files_message) { 'nothing to commit, working directory clean' }

        it 'does not commit' do
          expect(Open3).to_not receive(:capture3).with("git commit -a -m 'Autodeployer receipt file update'")

          subject.update_directory(dir)
        end

        it 'does not push' do
          expect(Open3).to_not receive(:capture3).with('git push')

          subject.update_directory(dir)
        end
      end
    end
  end
end
