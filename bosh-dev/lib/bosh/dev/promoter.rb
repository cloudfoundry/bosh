require 'logger'
require 'bosh/dev/build'
require 'bosh/dev/git_promoter'
require 'bosh/dev/git_tagger'
require 'bosh/dev/release_changes'

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
      end
    end
  end
end
