require 'spec_helper'
require 'bosh/dev/promoter'

module Bosh::Dev
  describe Promoter do
    describe '#promote' do
      let(:candidate_build_number) { 'fake-candidate_build_number' }
      let(:candidate_sha) { 'fake-candidate_sha' }
      let(:stable_branch) { 'fake-stable_branch' }

      let(:logger) { instance_double('Logger') }
      let(:build) { instance_double('Bosh::Dev::Build', promote_artifacts: nil) }
      let(:git_promoter) { instance_double('Bosh::Dev::GitPromoter', promote: nil) }
      let(:git_tagger) { instance_double('Bosh::Dev::GitTagger', tag_and_push: nil) }

      before do
        Logger.stub(:new).with(STDERR).and_return(logger)
        Build.stub(:candidate).and_return(build)
        GitPromoter.stub(:new).with(logger).and_return(git_promoter)
        GitTagger.stub(:new).with(logger).and_return(git_tagger)

        Rake::FileUtilsExt.stub(:sh)
      end

      subject(:promoter) do
        Promoter.new(candidate_build_number: candidate_build_number,
                     candidate_sha: candidate_sha,
                     stable_branch: stable_branch,
                     logger: logger)
      end

      it 'fetches new tags created since the last time the build ran' do
        promoter.stub(:system)
        Rake::FileUtilsExt.should_receive(:sh).with('git fetch --tags')

        promoter.promote
      end

      context 'when the current sha has never been promoted' do
        before do
          promoter.stub(:system).with("git fetch --tags && git tag --contains #{candidate_sha} | grep stable-").and_return(false)
        end

        it 'promotes artifacts' do
          build.should_receive(:promote_artifacts)

          promoter.promote
        end

        it 'promotes the candidate sha to the nominated stable branch (master by default)' do
          git_promoter.should_receive(:promote).with(candidate_sha, stable_branch)

          promoter.promote
        end

        it 'creates a new stable tag against the candidate sha' do
          git_tagger.should_receive(:tag_and_push).with(candidate_sha, candidate_build_number)

          promoter.promote
        end
      end

      context 'when the current sha has been promoted before' do
        before do
          promoter.stub(:system).with("git fetch --tags && git tag --contains #{candidate_sha} | grep stable-").and_return(true)
        end

        it 'skips promoting anything' do
          build.should_not_receive(:promote_artifacts)
          git_promoter.should_not_receive(:promote)
          git_tagger.should_not_receive(:tag_and_push)

          logger.should_receive(:info).with(/Skipping promotion/)

          promoter.promote
        end
      end
    end
  end
end
