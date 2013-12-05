require 'logger'
require 'bosh/core/shell'
require 'bosh/dev/build'
require 'bosh/dev/download_adapter'
require 'bosh/dev/git_promoter'
require 'bosh/dev/git_tagger'
require 'bosh/dev/git_promoter'
require 'bosh/dev/release_change_promoter'

module Bosh::Dev
  class Promoter
    def self.build(args)
      new(
        args.fetch(:candidate_build_number),
        args.fetch(:candidate_sha),
        args.fetch(:stable_branch),
        Logger.new(STDERR),
      )
    end

    def initialize(candidate_build_number, candidate_sha, stable_branch, logger)
      @candidate_build_number = candidate_build_number
      @candidate_sha = candidate_sha
      @stable_branch = stable_branch
      @logger = logger
    end

    def promote
      Rake::FileUtilsExt.sh('git fetch --tags')
      if system("git fetch --tags && git tag --contains #{@candidate_sha} | grep stable-")
        @logger.info('Skipping promotion since an existing stable tag was found')
      else
        build = Bosh::Dev::Build.candidate
        build.promote_artifacts

        final_release_sha = commit_final_release

        promoter = Bosh::Dev::GitPromoter.new(@logger)
        promoter.promote(final_release_sha, @stable_branch)

        tagger = Bosh::Dev::GitTagger.new(@logger)
        tagger.tag_and_push(final_release_sha, @candidate_build_number)

        merge_release_into_develop
      end
    end

    private

    def commit_final_release
      shell = Bosh::Core::Shell.new
      download_adapter = DownloadAdapter.new(@logger)

      shell.run("git checkout #{@candidate_sha}")

      release_change_promoter = ReleaseChangePromoter.new(@candidate_build_number, download_adapter)
      release_change_promoter.promote

      shell.run('git rev-parse HEAD')
    end

    def merge_release_into_develop
      shell = Bosh::Core::Shell.new
      shell.run('git fetch origin develop')

      shell.run("git merge origin/develop -m 'Merge final release for build #{@candidate_build_number} to develop'")
      shell.run('git push origin HEAD:develop')
    end
  end
end
