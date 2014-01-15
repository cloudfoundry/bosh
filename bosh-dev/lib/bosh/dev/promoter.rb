require 'logger'
require 'bosh/core/shell'
require 'bosh/dev/build'
require 'bosh/dev/download_adapter'
require 'bosh/dev/git_promoter'
require 'bosh/dev/git_tagger'
require 'bosh/dev/git_promoter'
require 'bosh/dev/git_branch_merger'
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
      tagger = GitTagger.new(@logger)

      if tagger.stable_tag_for?(@candidate_sha)
        @logger.info('Skipping promotion since an existing stable tag was found')
      else
        release_promoter = ReleaseChangePromoter.new(@candidate_build_number, @candidate_sha, DownloadAdapter.new(@logger))
        final_release_sha = release_promoter.promote

        promoter = GitPromoter.new(@logger)
        promoter.promote(final_release_sha, @stable_branch)

        tagger.tag_and_push(final_release_sha, @candidate_build_number)

        git_branch_merger = GitBranchMerger.new
        git_branch_merger.merge('develop', "Merge final release for build #{@candidate_build_number} to develop")

        build = Build.candidate
        build.promote_artifacts
      end
    end
  end
end
