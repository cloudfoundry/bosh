require 'spec_helper'
require 'bosh/dev/release_change_promoter'
require 'bosh/dev/download_adapter'

module Bosh::Dev
  describe ReleaseChangePromoter do
    let!(:patch_file) { Tempfile.new("#{build_number}-final-release") }
    before { allow(Tempfile).to receive(:new).and_return(patch_file) }
    before { allow(Dir).to receive(:pwd).and_return('fake-dir') }

    let(:build_number) { rand(1000) }
    let(:candidate_sha) { 'some-candidate-sha' }
    let(:final_release_sha) { 'final-release-sha' }
    let(:release_changes) { Bosh::Dev::ReleaseChangePromoter.new(build_number, candidate_sha, download_adapter, skip_release_promotion, logger) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }

    let(:release_patches_bucket) { Bosh::Dev::UriProvider::RELEASE_PATCHES_BUCKET }
    let(:patch_key) { "#{build_number}-final-release.patch" }

    before do
      allow(Open3).to receive(:capture3).
        and_return(['', '', instance_double('Process::Status', success?: true)])
    end

    describe '#promote' do
      describe 'when performing a release promotion' do
        let(:skip_release_promotion) { false }
        it "pulls down the staged changes from the build's bucket on s3" do
          allow(download_adapter).to receive(:download)
          patch_uri = 'http://www.example.com/tmp/build_patches/build_number.patch'
          allow(Bosh::Dev::UriProvider).to receive(:release_patches_uri).with('', "#{build_number}-final-release.patch").and_return(patch_uri)
          expect(download_adapter).to receive(:download).with(patch_uri, patch_file.path)

          release_changes.promote
        end

        it 'applies the changes via a git commit' do
          allow(download_adapter).to receive(:download).and_return(patch_file.path)

          success = ['', '', instance_double('Process::Status', success?: true)]
          expect(Open3).to receive(:capture3).with("git checkout #{candidate_sha}", chdir: 'fake-dir').and_return(success).ordered
          expect(Open3).to receive(:capture3).with('git checkout .', chdir: 'fake-dir').and_return(success).ordered
          expect(Open3).to receive(:capture3).with('git clean --force', chdir: 'fake-dir').and_return(success).ordered
          expect(Open3).to receive(:capture3).with("git apply #{patch_file.path}", chdir: 'fake-dir').and_return(success).ordered
          expect(Open3).to receive(:capture3).with('git add -A :/', chdir: 'fake-dir').and_return(success).ordered
          expect(Open3).to receive(:capture3).with("git commit -m 'Adding final release for build #{build_number}'", chdir: 'fake-dir').and_return(success).ordered

          release_changes.promote
        end

        it 'returns the sha after committing release changes' do
          expect(Open3).to receive(:capture3).with("git commit -m 'Adding final release for build #{build_number}'", chdir: 'fake-dir').
            and_return(['', '', instance_double('Process::Status', success?: true)]).ordered
          expect(Open3).to receive(:capture3).with('git rev-parse HEAD', chdir: 'fake-dir').
            and_return(["#{final_release_sha}\n", nil, instance_double('Process::Status', success?: true)]).ordered

          expect(release_changes.promote).to eq(final_release_sha)
        end
      end

      describe 'when skipping release promotion' do
        let(:skip_release_promotion) { true }
        it "does not pull down the staged changes from the build's bucket on s3" do
          expect(download_adapter).to_not receive(:download)
          release_changes.promote
        end

        it 'checks out the candidate sha and cleans' do
          allow(download_adapter).to receive(:download).and_return(patch_file.path)

          success = ['', '', instance_double('Process::Status', success?: true)]
          expect(Open3).to receive(:capture3).with("git checkout #{candidate_sha}", chdir: 'fake-dir').and_return(success).ordered
          expect(Open3).to receive(:capture3).with('git checkout .', chdir: 'fake-dir').and_return(success).ordered
          expect(Open3).to receive(:capture3).with('git clean --force', chdir: 'fake-dir').and_return(success).ordered

          release_changes.promote
        end

        it 'returns the candidate sha' do
          expect(release_changes.promote).to eq(candidate_sha)
        end
      end
    end
  end
end
