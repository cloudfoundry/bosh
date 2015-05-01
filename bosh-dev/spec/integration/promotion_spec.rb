require 'spec_helper'
require 'bosh/dev/download_adapter'
require 'bosh/dev/local_download_adapter'
require 'bosh/dev/promoter'
require 'bosh/dev/git_tagger'
require 'bosh/dev/git_branch_merger'
require 'open3'
require 'bosh/dev/command_helper'

describe 'promotion' do
  let!(:origin_repo_path) { Dir.mktmpdir(['promote_test_repo', '.git']) }
  after { FileUtils.rm_rf(origin_repo_path) }

  let!(:workspace_path) { Dir.mktmpdir('promote_test_workspace') }
  after { FileUtils.rm_rf(workspace_path) }

  before do
    Dir.chdir(origin_repo_path) do
      exec_cmd('git init --bare .')
    end
    Dir.chdir(workspace_path) do
      exec_cmd("git clone #{origin_repo_path} .")
      config_git_user
      File.write('initial-file.go', 'initial-code')
      exec_cmd('git add -A')
      exec_cmd("git commit -m 'initial commit'")
      exec_cmd('git push origin master')
    end
    # recreate workspace dir
    FileUtils.rm_rf(workspace_path)
    Dir.mkdir(workspace_path)
  end

  before do
    allow(Bosh::Dev::DownloadAdapter).to(receive(:new).with(logger)) { Bosh::Dev::LocalDownloadAdapter.new(logger) }
  end

  let!(:release_patch_file) { Tempfile.new(['promote_test_release', '.patch']) }
  after { release_patch_file.delete }

  it 'commits the release patch to a stable tag and then merges to the master and feature branches' do
    candidate_sha = nil
    Dir.chdir(workspace_path) do
      # feature development
      exec_cmd("git clone #{origin_repo_path} .")
      config_git_user
      exec_cmd('git checkout master')
      exec_cmd('git checkout -b feature_branch')
      File.write('feature-file.go', 'feature-code')
      exec_cmd('git add -A')
      exec_cmd("git commit -m 'added new file'")
      exec_cmd('git push origin feature_branch')

      # get candidate sha (begining of CI pipeline)
      candidate_sha = exec_cmd('git rev-parse HEAD').first.strip

      # release creation (middle of CI pipeline)
      File.write('release-file.go', 'release-code')
      exec_cmd('git add -A')
      exec_cmd("git diff --staged > #{release_patch_file.path}")
    end

    # recreate workspace dir
    FileUtils.rm_rf(workspace_path)
    Dir.mkdir(workspace_path)

    # promote (end of CI pipeline)
    Dir.chdir(workspace_path) do
      exec_cmd("git clone #{origin_repo_path} .")
      config_git_user
      exec_cmd('git checkout feature_branch')

      # instead of getting the patch from S3, copy from the local patch file
      allow(Bosh::Dev::UriProvider).to receive(:release_patches_uri).with('', '0000-final-release.patch').and_return(release_patch_file.path)

      # disable promotion of stemcells, gems & the release
      build = instance_double('Bosh::Dev::Build', promote: nil, promoted?: false)
      allow(Bosh::Dev::Build).to receive(:candidate).and_return(build)

      rake_input_args = {
        candidate_build_number: '0000',
        candidate_sha: candidate_sha,
        feature_branch: 'feature_branch',
        stable_branch: 'master',
      }
      promoter = Bosh::Dev::Promoter.build(rake_input_args)
      promoter.promote

      # expect new tag stable-0000 to exist
      tagger = Bosh::Dev::GitTagger.new(logger)
      tag_sha = tagger.tag_sha('stable-0000') # errors if tag does not exist
      expect(tag_sha).to_not be_empty

      # expect sha of tag to be in feature_branch and master
      merger = Bosh::Dev::GitBranchMerger.new(logger)
      expect(merger.branch_contains?('master', tag_sha)).to be(true)
      expect(merger.branch_contains?('feature_branch', tag_sha)).to be(true)
    end
  end
end
