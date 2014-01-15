require 'spec_helper'
require 'bosh/dev/promoter'

module Bosh::Dev
  describe Promoter do
    describe '.build' do
      it 'constructs a promoter, injects the logger' do
        promoter = double('promoter')
        logger = double('logger')
        Logger.stub(:new).with(STDERR).and_return(logger)

        expect(Bosh::Dev::Promoter).to receive(:new).with(
                                         321,
                                         'deadbeef',
                                         'stable',
                                         logger,
                                       ).and_return(promoter)

        expect(
          Bosh::Dev::Promoter.build(
            candidate_build_number: 321,
            candidate_sha: 'deadbeef',
            stable_branch: 'stable',
          )
        ).to eq(promoter)
      end
    end

    describe '#promote' do
      let(:candidate_build_number) { 'fake-candidate_build_number' }
      let(:candidate_sha) { 'fake-candidate_sha' }
      let(:stable_branch) { 'fake-stable_branch' }
      let(:final_release_sha) { 'fake-final-release-sha' }

      let(:logger) { instance_double('Logger', info: nil) }
      let(:build) { instance_double('Bosh::Dev::Build', promote_artifacts: nil) }
      let(:git_promoter) { instance_double('Bosh::Dev::GitPromoter', promote: nil) }
      let(:git_tagger) { instance_double('Bosh::Dev::GitTagger', tag_and_push: nil, stable_tag_for?: nil) }
      let(:git_branch_merger) { instance_double('Bosh::Dev::GitBranchMerger', merge: nil) }
      let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }
      let(:release_change_promoter) { instance_double('Bosh::Dev::ReleaseChangePromoter', promote: nil) }

      before do
        Logger.stub(:new).with(STDERR).and_return(logger)
        Build.stub(:candidate).and_return(build)
        GitPromoter.stub(:new).with(logger).and_return(git_promoter)
        GitTagger.stub(:new).with(logger).and_return(git_tagger)
        GitBranchMerger.stub(:new).and_return(git_branch_merger)

        Bosh::Dev::DownloadAdapter.stub(:new).and_return(download_adapter)
        Bosh::Dev::ReleaseChangePromoter.stub(:new).with(candidate_build_number, candidate_sha, download_adapter).and_return(
          release_change_promoter)

      end

      subject(:promoter) do
        Promoter.new(
          candidate_build_number,
          candidate_sha,
          stable_branch,
          logger,
        )
      end

      context 'when the current sha has never been promoted' do
        before do
          git_tagger.stub(:stable_tag_for?).with(candidate_sha).and_return(false)
        end

        it 'promotes the candidate sha to the nominated stable branch (master by default)' do
          release_change_promoter.stub(:promote).and_return(final_release_sha)
          git_promoter.should_receive(:promote).with(final_release_sha, stable_branch)

          promoter.promote
        end

        it 'creates a new stable tag against the candidate sha' do
          release_change_promoter.stub(:promote).and_return(final_release_sha)

          git_tagger.should_receive(:tag_and_push).with(final_release_sha, candidate_build_number)

          promoter.promote
        end

        it 'commits a record of the final release to the git repo' do
          expect(release_change_promoter).to receive(:promote).ordered
          expect(git_branch_merger).to receive(:merge).with('develop', "Merge final release for build #{candidate_build_number} to develop").ordered

          promoter.promote
        end

        it 'promotes artifacts' do
          build.should_receive(:promote_artifacts)

          promoter.promote
        end
      end

      context 'when the current sha has been promoted before' do
        before do
          git_tagger.stub(:stable_tag_for?).with(candidate_sha).and_return(true)
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
