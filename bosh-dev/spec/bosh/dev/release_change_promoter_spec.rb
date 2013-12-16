require 'spec_helper'
require 'bosh/dev/release_change_promoter'
require 'bosh/dev/download_adapter'

module Bosh::Dev
  describe ReleaseChangePromoter do
    let!(:patch_file) { Tempfile.new("#{build_number}-final-release") }
    before { Tempfile.stub(new: patch_file) }

    let(:build_number) { rand(1000) }
    let(:candidate_sha) { 'some-candidate-sha' }
    let(:final_release_sha) { 'final-release-sha' }
    let(:release_changes) { Bosh::Dev::ReleaseChangePromoter.new(build_number, candidate_sha, download_adapter) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }
    let(:shell) { instance_double('Bosh::Core::Shell') }
    before { Bosh::Core::Shell.stub(new: shell) }

    let(:release_patches_bucket) { Bosh::Dev::UriProvider::RELEASE_PATCHES_BUCKET }
    let(:patch_key) { "#{build_number}-final-release.patch" }

    before { shell.stub(:run) }

    describe '#promote' do
      it "pulls down the staged changes from the build's bucket on s3" do
        download_adapter.stub(:download)
        patch_uri = 'http://www.example.com/tmp/build_patches/build_number.patch'
        Bosh::Dev::UriProvider.stub(:release_patches_uri).with('', "#{build_number}-final-release.patch").and_return(patch_uri)
        download_adapter.should_receive(:download).with(patch_uri, patch_file.path)

        release_changes.promote
      end

      it 'applies the changes via a git commit' do
        download_adapter.stub(:download).and_return(patch_file.path)

        expect(shell).to receive(:run).with("git checkout #{candidate_sha}").ordered
        expect(shell).to receive(:run).with('git checkout .').ordered
        expect(shell).to receive(:run).with('git clean --force').ordered
        expect(shell).to receive(:run).with("git apply #{patch_file.path}").ordered
        expect(shell).to receive(:run).with('git add -A :/').ordered
        expect(shell).to receive(:run).with("git commit -m 'Adding final release for build #{build_number}'").ordered

        release_changes.promote
      end

      it 'returns the sha after committing release changes' do
        expect(shell).to receive(:run).with("git commit -m 'Adding final release for build #{build_number}'").ordered
        expect(shell).to receive(:run).with('git rev-parse HEAD').ordered.and_return(final_release_sha)

        expect(release_changes.promote).to eq(final_release_sha)
      end
    end
  end
end
