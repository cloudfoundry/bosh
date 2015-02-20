require 'spec_helper'
require 'fakefs/spec_helpers'

require 'bosh/dev/upload_adapter'
require 'bosh/dev/release_change_stager'

module Bosh::Dev
  describe ReleaseChangeStager do
    describe '#stage' do
      include FakeFS::SpecHelpers
      before { FileUtils.mkpath(Dir.tmpdir) }

      let(:build_number) { 1234 }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter', upload: nil) }
      let(:shell) { instance_double('Bosh::Core::Shell') }
      before { allow(Bosh::Core::Shell).to receive_messages(new: shell) }

      let(:release_patches_bucket) { Bosh::Dev::UriProvider::RELEASE_PATCHES_BUCKET }
      let(:patch_key) { "#{build_number}-final-release.patch" }
      let(:work_tree) { Dir.mktmpdir }

      subject(:stager) { Bosh::Dev::ReleaseChangeStager.new(work_tree, build_number, upload_adapter) }

      it 'creates a patch file from git diff' do
        expect(shell).to receive(:run).with("git --work-tree=#{work_tree} --git-dir=#{work_tree}/.git add -A :/").ordered
        expect(shell).to receive(:run).with(%r{git --work-tree=#{work_tree} --git-dir=#{work_tree}/.git diff --staged > .*/}).ordered

        stager.stage
      end

      it 'saves the changes on the filesystem to a patch file in the appropriate bucket on s3' do
        patch_file = double('patch_file', path: nil)
        allow(Tempfile).to receive(:new).with('1234-final-release').and_return(patch_file)

        allow(shell).to receive(:run)
        expect(upload_adapter).to receive(:upload).with(
          bucket_name: release_patches_bucket,
          key: patch_key,
          body: patch_file,
          public: true,
        )

        stager.stage
      end
    end

    context 'with a real shell' do
      let(:work_tree) { Dir.mktmpdir }
      before do
        Dir.chdir(work_tree) do
          `git init`
          `git commit --allow-empty -m 'Initial commit'`
          File.write('new_file', "hello\n")
        end
      end
      let(:build_number) { 1234 }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }
      subject(:stager) { Bosh::Dev::ReleaseChangeStager.new(work_tree, build_number, upload_adapter) }

      after do
        FileUtils.rmtree(work_tree)
      end

      it 'does not commit changes' do
        allow(upload_adapter).to receive(:upload)

        expect { stager.stage }.to_not change { `git --git-dir=#{work_tree}/.git rev-parse HEAD` }
      end

      it 'generates a patch containing the changes' do
        expect(upload_adapter).to receive(:upload).with(
          hash_including(
            body: include("+hello\n"),
          )
        )
        stager.stage
      end
    end
  end
end
