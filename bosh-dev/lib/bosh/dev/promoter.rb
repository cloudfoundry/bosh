require 'bosh/core/shell'
require 'bosh/dev/build'
require 'bosh/dev/download_adapter'
require 'bosh/dev/git_promoter'
require 'bosh/dev/git_tagger'
require 'bosh/dev/git_promoter'
require 'bosh/dev/git_branch_merger'
require 'bosh/dev/release_change_promoter'
require 'logging'

module Bosh::Dev
  class Promoter

    class Stage
      attr_reader :name, :logger
      def initialize(name, logger)
        @name = name
        @logger = logger
      end
    end

    def self.build(args)
      new(
        args.fetch(:candidate_build_number),
        args.fetch(:candidate_sha),
        args.fetch(:feature_branch),
        args.fetch(:stable_branch),
        Logging.logger(STDERR),
      )
    end

    def initialize(candidate_build_number, candidate_sha, feature_branch, stable_branch, logger)
      @candidate_build_number = candidate_build_number
      @candidate_sha = candidate_sha
      @feature_branch = feature_branch
      @stable_branch = stable_branch
      @logger = logger
    end

    def promote
      stage_args = {
        candidate_build_number: @candidate_build_number,
        candidate_sha: @candidate_sha,
        feature_branch: @feature_branch,
        stable_branch: @stable_branch,
      }
      stages.each do |stage|
        if stage.promoted?(stage_args)
          @logger.info("Skipping #{stage.name} promotion stage")
        else
          @logger.info("Executing #{stage.name} promotion stage")
          stage.promote(stage_args)
        end
      end
    end

    private

    def stages
      [
        ApplyPromoteTagPushStage.new(@logger),
        BuildCandidateArtifactPromotionStage.new(@logger),
        GitBranchMergeStage.new(@logger),
      ]
    end

    class ApplyPromoteTagPushStage < Stage
      def initialize(logger)
        super('Apply, Promote, Tag & Push', logger)
        @promoter = GitPromoter.new(Dir.pwd, logger)
        @tagger = GitTagger.new(logger)
        @downloader = DownloadAdapter.new(logger)
      end

      def promote(stage_args)
        candidate_build_number = stage_args.fetch(:candidate_build_number)
        candidate_sha = stage_args.fetch(:candidate_sha)
        stable_branch = stage_args.fetch(:stable_branch)

        release_promoter = ReleaseChangePromoter.new(candidate_build_number, candidate_sha, @downloader, skip_release_promotion, logger)
        final_release_sha = release_promoter.promote
        @promoter.promote(final_release_sha, stable_branch)

        @tagger.tag_and_push(final_release_sha, candidate_build_number)
      end

      # returns true if any stable tag contains the candidate_sha
      def promoted?(stage_args)
        @tagger.stable_tag_for?(stage_args.fetch(:candidate_sha))
      end

      private

      def skip_release_promotion
        @skip_release_promotion ||= ENV.fetch('SKIP_PROMOTE_ARTIFACTS', '').split(',').include?('release')
      end
    end

    class BuildCandidateArtifactPromotionStage < Stage
      def initialize(logger)
        super('Build Candidate Artifacts', logger)
        @build_candidate = Build.candidate
      end

      def promote(stage_args)
        @build_candidate.promote
      end

      def promoted?(stage_args)
        @build_candidate.promoted?
      end
    end

    class GitBranchMergeStage < Stage
      def initialize(logger)
        super('Merge Release Commit to Feature Branch', logger)
        @tagger = GitTagger.new(logger)
        @merger = GitBranchMerger.new(Dir.pwd, logger)
      end

      def promote(stage_args)
        candidate_build_number = stage_args.fetch(:candidate_build_number)
        feature_branch = stage_args.fetch(:feature_branch)

        final_release_sha = @tagger.stable_tag_sha(candidate_build_number)
        @merger.merge(
          final_release_sha,
          feature_branch,
          "Merge final release for build #{candidate_build_number} to #{feature_branch}",
        )
      end

      # returns true if the stable tag's sha has been merged back to the feature branch
      def promoted?(stage_args)
        candidate_build_number = stage_args.fetch(:candidate_build_number)
        feature_branch = stage_args.fetch(:feature_branch)

        final_release_sha = @tagger.stable_tag_sha(candidate_build_number)
        @merger.branch_contains?(feature_branch, final_release_sha)
      end
    end
  end
end
