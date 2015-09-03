require 'spec_helper'
require 'bosh/dev/git_repo_updater'

module Bosh::Dev
  describe GitRepoUpdater do
    subject(:git_repo_updater) { described_class.new(logger) }

    let(:remote_dir) { Dir.mktmpdir('git-repo-updater-remote') }
    let(:local_dir) { Dir.mktmpdir('git-repo-updater-local') }
    before do
      Dir.chdir(remote_dir) do
        `git init`
        config_git_user
        File.write('README.md', 'hiya!')
        `git add .`
        `git commit -m 'Initial commit'`
      end

      FileUtils.rm_rf(local_dir)
      `git clone #{remote_dir} #{local_dir}`

      Dir.chdir(remote_dir) { `git checkout -b another-branch` }
    end

    after do
      FileUtils.rm_rf(remote_dir)
      FileUtils.rm_rf(local_dir)
    end

    context 'when there are changes' do
      before do
        Dir.chdir(local_dir) do
          config_git_user
          File.write('README.md', 'new contents')
        end
      end

      it 'commits and pushes the changes' do
        original_commit = get_head_commit(remote_dir)
        git_repo_updater.update_directory(local_dir, 'my commit message')
        expect(get_head_commit(remote_dir)).not_to eq(original_commit)
        expect(get_head_commit_message(remote_dir)).to eq('my commit message')
      end

      context 'when pushing changes fails to rebase' do
        before do
          Dir.chdir(remote_dir) do
            config_git_user
            `git checkout master`
            File.write('README.md', 'remote changes')
            `git commit -am 'Remote commit'`
            `git checkout -b another-branch`
          end
        end

        it 'raises PushNonFastForwardError' do
          expect {
            git_repo_updater.update_directory(local_dir, 'my commit message')
          }.to raise_error /Failed to git pull/
        end
      end

      context 'when pushing changes fails because of non-fast-forward push' do
        before do
          Dir.chdir(remote_dir) do
            config_git_user
            `git checkout master`
            File.write('non-conflict', 'remote changes')
            `git commit -am 'Remote commit'`
            `git checkout -b another-branch`
          end
        end

        it 'tries to rebase' do
          git_repo_updater.update_directory(local_dir, 'my commit message')
          expect(get_head_commit_message(remote_dir)).to eq('Initial commit')
        end
      end
    end

    context 'when there are no changes' do
      it 'does not commit anything' do
        original_commit = get_head_commit(remote_dir)
        git_repo_updater.update_directory(local_dir, 'my commit message')
        expect(get_head_commit(remote_dir)).to eq(original_commit)
        expect(get_head_commit_message(remote_dir)).to eq('Initial commit')
      end
    end

    def get_head_commit(repo)
      Dir.chdir(repo) { `git rev-parse master` }.chomp
    end

    def get_head_commit_message(repo)
      Dir.chdir(repo) { `git log --format=%B -1 master` }.chomp.chomp
    end
  end
end
