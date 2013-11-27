require 'spec_helper'
require 'bosh/dev/upload_adapter'
require 'bosh/dev/download_adapter'
require 'bosh/dev/release_change_stager'

module Bosh::Dev
  describe ReleaseChangeStager do
    let!(:patch_file) { Tempfile.new("#{build_number}-final-release") }
    before { Tempfile.stub(new: patch_file) }

    let(:build_number) { rand(1000) }
    let(:release_changes) { Bosh::Dev::ReleaseChangeStager.new(build_number, upload_adapter, download_adapter) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }
    let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter', upload: nil) }
    let(:shell) { instance_double('Bosh::Core::Shell') }
    before { Bosh::Core::Shell.stub(new: shell) }

    let(:release_patches_bucket) { Bosh::Dev::UriProvider::RELEASE_PATCHES_BUCKET }
    let(:patch_key) { "#{build_number}-final-release.patch" }

    describe '#stage' do
      it 'creates a patch file from git diff' do
        shell.should_receive(:run).with('git add -A :/').ordered
        shell.should_receive(:run).with("git diff --staged > #{ patch_file.path }").ordered

        release_changes.stage
      end

      it 'saves the changes on the filesystem to a patch file in the appropriate bucket on s3' do
        shell.stub(:run)
        upload_adapter.should_receive(:upload).with(bucket_name: release_patches_bucket, key: patch_key, body: patch_file, public: true)

        release_changes.stage
      end

      context 'with a real shell' do
        let(:shell) { Bosh::Core::Shell.new }

        after do
          `git reset`
        end

        it 'does not commit changes' do
          expect { release_changes.stage }.to_not change { `git status --porcelain | wc -l` }
        end
      end

    end

    describe '#promote' do
      it "pulls down the staged changes from the build's bucket on s3" do
        download_adapter.stub(:download)
        shell.stub(:run)
        patch_uri = 'http://www.example.com/tmp/build_patches/build_number.patch'
        Bosh::Dev::UriProvider.stub(:release_patches_uri).with('tmp/build_patches', "#{build_number}-final-release.patch").and_return(patch_uri)
        download_adapter.should_receive(:download).with(patch_uri, patch_file.path)

        release_changes.promote
      end

      it 'applies the changes via a git commit' do
        download_adapter.stub(:download).and_return(patch_file.path)

        shell.should_receive(:run).with("git apply #{patch_file.path}").ordered
        shell.should_receive(:run).with("git commit -m 'Adding final release for build #{build_number}'").ordered

        release_changes.promote
      end
    end
  end
end
