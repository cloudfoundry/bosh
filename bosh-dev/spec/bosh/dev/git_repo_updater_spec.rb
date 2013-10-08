require 'spec_helper'
require 'bosh/dev/git_repo_updater'

module Bosh::Dev
  describe GitRepoUpdater do
    include FakeFS::SpecHelpers

    subject(:git_repo_updater) { described_class.new }

    let(:dir) { '/some/dir' }

    before do
      Open3.stub(capture3: ['', '', instance_double('Process::Status', success?: true)])
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
  end
end
