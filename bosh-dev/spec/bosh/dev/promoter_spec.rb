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

      let(:logger) { instance_double('Logger', info: nil) }
      let(:build) { instance_double('Bosh::Dev::Build', promote_artifacts: nil) }
      let(:git_promoter) { instance_double('Bosh::Dev::GitPromoter', promote: nil) }
      let(:git_tagger) { instance_double('Bosh::Dev::GitTagger', tag_and_push: nil) }
      let(:shell) { instance_double('Bosh::Core::Shell', run: nil) }
      let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }

      before do
        Logger.stub(:new).with(STDERR).and_return(logger)
        Build.stub(:candidate).and_return(build)
        GitPromoter.stub(:new).with(logger).and_return(git_promoter)
        GitTagger.stub(:new).with(logger).and_return(git_tagger)

        Rake::FileUtilsExt.stub(:sh)
        Bosh::Core::Shell.stub(:new).and_return(shell)
        Bosh::Dev::DownloadAdapter.stub(:new).and_return(download_adapter)
      end

      subject(:promoter) do
        Promoter.new(
          candidate_build_number,
          candidate_sha,
          stable_branch,
          logger,
        )
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

        it 'commits a record of the final release to the git repo' do

          release_change_promoter = instance_double('Bosh::Dev::ReleaseChangePromoter')
          Bosh::Dev::ReleaseChangePromoter.stub(:new).with(candidate_build_number, download_adapter).and_return(
            release_change_promoter)

          expect(shell).to receive(:run).with('git pull').ordered
          expect(release_change_promoter).to receive(:promote)
          expect(shell).to receive(:run).with('git push origin develop').ordered

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
