require 'logger'
require 'bosh/dev/build'
require 'bosh/dev/git_promoter'
require 'bosh/dev/git_tagger'

module Bosh::Dev
  class Promoter
    def initialize(options)
      @candidate_build_number = options.fetch(:candidate_build_number)
      @candidate_sha = options.fetch(:candidate_sha)
      @stable_branch = options.fetch(:stable_branch)
      @logger = options.fetch(:logger)
    end

    def promote
      Rake::FileUtilsExt.sh('git fetch --tags')
      if system('git fetch --tags && git tag --points-at HEAD | grep stable-')
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
