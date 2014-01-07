require 'spec_helper'
require 'bosh/dev/git_repo_updater'

module Bosh::Dev
  describe GitRepoUpdater do
    include FakeFS::SpecHelpers

    subject(:git_repo_updater) { described_class.new }

    let(:dir) { '/some/dir' }

    before do
      Open3.stub(capture3: ['', '', instance_double('Process::Status', success?: true)])
      Open3.stub(:capture3).with('git', 'status') do
        ['', '', instance_double('Process::Status', success?: true)]
      end

      FileUtils.mkdir_p(dir)
    end

    it 'changes to the directory' do
      Dir.should_receive(:chdir).with(dir)

      subject.update_directory(dir)
    end

    it 'adds untracked files' do
      Open3.should_receive(:capture3).with('git', 'add', '.')

      subject.update_directory(dir)
    end

    it 'adds modified files' do
      Open3.should_receive(:capture3).with('git', 'commit', '-a', '-m', 'Autodeployer receipt file update')

      subject.update_directory(dir)
    end

    it 'git pushes' do
      Open3.should_receive(:capture3).with('git', 'push')

      subject.update_directory(dir)
    end

    context 'when there are no modified files to commit' do
      before do
        Open3.stub(:capture3).with('git', 'status') do
          [no_modified_files_message, '',
           instance_double('Process::Status', success?: true)]
        end
      end

      context 'when the message has parantheses' do
        let(:no_modified_files_message) { 'nothing to commit (working directory clean)' }

        it 'does not commit' do
          Open3.should_not_receive(:capture3).with('git', 'commit', '-a', '-m', 'Autodeployer receipt file update')
          subject.update_directory(dir)
        end

        it 'does not push' do
          Open3.should_not_receive(:capture3).with('git', 'push')
          subject.update_directory(dir)
        end
      end

      context 'when the message has a comma' do
        let(:no_modified_files_message) { 'nothing to commit, working directory clean' }

        it 'does not commit' do
          Open3.should_not_receive(:capture3).with('git', 'commit', '-a', '-m', 'Autodeployer receipt file update')
          subject.update_directory(dir)
        end

        it 'does not push' do
          Open3.should_not_receive(:capture3).with('git', 'push')
          subject.update_directory(dir)
        end
      end
    end
  end
end
