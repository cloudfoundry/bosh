require 'spec_helper'
require 'bosh/dev/promoter'

module Bosh::Dev
  describe Promoter do
    describe '.build' do
      it 'constructs a promoter, injects the logger' do
        promoter = double('promoter')
        expect(Bosh::Dev::Promoter).to receive(:new).with(
          321,
          'deadbeef',
          'develop',
          'stable',
          logger,
        ).and_return(promoter)

        expect(
          Bosh::Dev::Promoter.build(
            candidate_build_number: 321,
            candidate_sha: 'deadbeef',
            feature_branch: 'develop',
            stable_branch: 'stable',
          )
        ).to eq(promoter)
      end
    end

    describe '#promote' do
      let(:candidate_build_number) { 'fake-candidate_build_number' }
      let(:candidate_sha) { 'fake-candidate_sha' }
      let(:stable_branch) { 'fake-stable_branch' }
      let(:feature_branch) { 'fake-feature-branch' }
      let(:final_release_sha) { 'fake-final-release-sha' }
      let(:stable_tag_name) { 'fake-stable-tag-name' }
      let(:stable_tag_sha) { 'fake-stable-tag-sha' }

      let(:build) { instance_double('Bosh::Dev::Build', promote: nil) }
      let(:git_promoter) { instance_double('Bosh::Dev::GitPromoter', promote: nil) }
      let(:git_tagger) { instance_double('Bosh::Dev::GitTagger', tag_and_push: nil) }
      let(:git_branch_merger) { instance_double('Bosh::Dev::GitBranchMerger', merge: nil) }
      let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }
      let(:release_change_promoter) { instance_double('Bosh::Dev::ReleaseChangePromoter', promote: nil) }

      before do
        allow(Build).to receive(:candidate).and_return(build)
        allow(GitPromoter).to receive(:new).with(logger).and_return(git_promoter)
        allow(GitTagger).to receive(:new).with(logger).and_return(git_tagger)
        allow(GitBranchMerger).to receive(:new).with(logger).and_return(git_branch_merger)

        allow(Bosh::Dev::DownloadAdapter).to receive(:new).and_return(download_adapter)
        allow(Bosh::Dev::ReleaseChangePromoter).to receive(:new).with(
          candidate_build_number,
          candidate_sha,
          download_adapter,
          logger
        ).and_return(release_change_promoter)

      end

      subject(:promoter) do
        Promoter.new(
          candidate_build_number,
          candidate_sha,
          feature_branch,
          stable_branch,
          logger,
        )
      end

      before do
        allow(build).to receive(:promoted?).and_return(false)

        allow(git_tagger).to receive(:stable_tag_sha).with(candidate_build_number).and_return(stable_tag_sha)
        allow(git_tagger).to receive(:stable_tag_for?).with(candidate_sha).and_return(false)

        allow(git_branch_merger).to receive(:branch_contains?).with(feature_branch, stable_tag_sha).and_return(false)
      end

      context 'when the current sha has never been promoted' do
        before do
          allow(git_tagger).to receive(:stable_tag_for?).with(candidate_sha).and_return(false)
        end

        it 'promotes the candidate sha to the nominated stable branch (master by default)' do
          expect(release_change_promoter).to receive(:promote).and_return(final_release_sha)
          expect(git_promoter).to receive(:promote).with(final_release_sha, stable_branch)

          promoter.promote
        end

        it 'creates a new stable tag against the candidate sha' do
          expect(release_change_promoter).to receive(:promote).and_return(final_release_sha)

          expect(git_tagger).to receive(:tag_and_push).with(final_release_sha, candidate_build_number)

          promoter.promote
        end

        it 'commits a record of the final release to the git repo' do
          expect(release_change_promoter).to receive(:promote).ordered
          expect(git_branch_merger).to receive(:merge).with(
            stable_tag_sha,
            'fake-feature-branch',
            "Merge final release for build #{candidate_build_number} to fake-feature-branch"
          ).ordered

          promoter.promote
        end

        it 'promotes artifacts' do
          expect(build).to receive(:promote)

          promoter.promote
        end
      end

      context 'when the current sha has been promoted before' do
        before do
          allow(git_tagger).to receive(:stable_tag_for?).with(candidate_sha).and_return(true)
        end

        it 'skips git promotion' do
          expect(git_promoter).to_not receive(:promote)
          expect(git_tagger).to_not receive(:tag_and_push)

          promoter.promote

          expect(log_string).to include('Skipping Apply, Promote, Tag & Push promotion stage')
        end

        it 'still attempts to promote the artifacts' do
          expect(build).to receive(:promote)

          promoter.promote
        end

        it 'still attempts to merge feature branch to stable branch' do
          expect(git_branch_merger).to receive(:merge).with(
            stable_tag_sha,
            'fake-feature-branch',
            "Merge final release for build #{candidate_build_number} to fake-feature-branch"
          )

          promoter.promote
        end

        context 'when the artifacts have been promoted before' do
          before do
            allow(build).to receive(:promoted?).and_return(true)
          end

          it 'skips promoting the artifacts' do
            expect(build).to_not receive(:promote)

            promoter.promote
          end

          it 'still attempts to merge feature branch to stable branch' do
            expect(git_branch_merger).to receive(:merge).with(
              stable_tag_sha,
              'fake-feature-branch',
              "Merge final release for build #{candidate_build_number} to fake-feature-branch"
            )

            promoter.promote
          end

          context 'when the feature branch has been merged to the stable branch' do
            before do
              allow(git_branch_merger).to receive(:branch_contains?).with(feature_branch, stable_tag_sha).and_return(true)
            end

            it 'skips merging feature branch to stable branch' do
              expect(git_branch_merger).to_not receive(:merge)

              promoter.promote
            end
          end
        end
      end
    end
  end
end
