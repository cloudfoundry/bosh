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

        promoter = Bosh::Dev::GitPromoter.new(@logger)
        promoter.promote(@candidate_sha, @stable_branch)

        tagger = Bosh::Dev::GitTagger.new(@logger)
        tagger.tag_and_push(@candidate_sha, @candidate_build_number)

        # we actually push commits after the tagging in order to prevent untested code from
        # leaking into the tag
        commit_final_release
      end
    end

    private

    def commit_final_release
      shell = Bosh::Core::Shell.new
      download_adapter = DownloadAdapter.new(@logger)

      shell.run('git pull')

      release_change_promoter = ReleaseChangePromoter.new(@candidate_build_number, download_adapter)
      release_change_promoter.promote

      # assume we are pushing to the 'develop' branch as we only have the concept of a candidate SHA
      shell.run('git push origin develop')
    end
  end
end
