require 'spec_helper'

module Bosh::Cli
  describe ReleaseCompiler do
    subject(:release_compiler) do
      described_class.new(release_manifest_file, artifacts_dir, blobstore, [], release_source.path)
    end
    let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
    let(:workspace_dir) { Dir.mktmpdir('release-compiler-spec') }
    let(:artifacts_dir) { File.join(workspace_dir, 'artifacts') }

    after { FileUtils.rm_rf(workspace_dir); release_source.cleanup }

    let(:blobstore) { Bosh::Blobstore::Client.create('local', 'blobstore_path' => blobstore_dir) }
    let(:blobstore_dir) { File.join(workspace_dir, 'blobstore') }

    let(:job_tarball) { Tempfile.new('job-tarball', workspace_dir) }
    let(:package_tarball) { Tempfile.new('package-tarball', workspace_dir) }
    let(:license_tarball) { Tempfile.new('license-tarball', workspace_dir) }
    before do
      blobstore.create(File.read(job_tarball), 'fake-job-blobstore_id')
      blobstore.create(File.read(package_tarball), 'fake-package-blobstore_id')
      blobstore.create(File.read(license_tarball), 'fake-license-blobstore_id')
    end

    let(:release_manifest_file) { File.join(workspace_dir, 'release-1.yml') }
    let(:release_index) { Versions::VersionsIndex.new(workspace_dir) }
    let(:original_release_manifest) do
      {
        'name' => 'fake-release-name',
        'version' => 'fake-release-version'
      }
    end
    let(:release_manifest) { original_release_manifest }

    before { File.write(release_manifest_file, YAML.dump(release_manifest)) }

    describe '#compile' do
      let(:release_tarball_file) { File.join(workspace_dir, 'fake-release-name-fake-release-version.tgz') }

      context 'when packages exist' do
        before do
          release_source.add_version(
            'fake-package-fingerprint',
            '.final_builds/packages/fake-package-name',
            File.read(package_tarball),
            {
              'version' => 'fake-package-fingerprint',
              'blobstore_id' => 'fake-package-blobstore_id',
            }
          )
        end

        let(:release_manifest) do
          original_release_manifest.merge(
            'packages' => [{
              'name' => 'fake-package-name',
              'version' => 'fake-package-fingerprint',
              'sha1' => Digest::SHA1.file(package_tarball).hexdigest,
              'fingerpint' => 'fake-package-fingerprint',
              'blobstore_id' => 'fake-package-blobstore_id',
            }])
        end

        it 'copies packages' do
          release_compiler.compile
          expect(list_tar_files(release_tarball_file)).to include('./packages/fake-package-name.tgz')
        end
      end

      context 'when jobs exist' do
        before do
          release_source.add_version(
            'fake-job-fingerprint',
            '.final_builds/jobs/fake-job-name',
            File.read(job_tarball),
            {
              'version' => 'fake-job-fingerprint',
              'blobstore_id' => 'fake-job-blobstore_id',
            }
          )
        end

        let(:release_manifest) do
          original_release_manifest.merge(
            'jobs' => [{
              'name' => 'fake-job-name',
              'version' => 'fake-job-fingerprint',
              'sha1' => Digest::SHA1.file(job_tarball).hexdigest,
              'fingerpint' => 'fake-job-fingerprint',
              'blobstore_id' => 'fake-job-blobstore_id',
            }])
        end

        it 'copies jobs' do
          release_compiler.compile
          expect(list_tar_files(release_tarball_file)).to include('./jobs/fake-job-name.tgz')
        end
      end

      context 'when license exists' do
        before do
          release_source.add_version(
            'fake-license-fingerprint',
            '.final_builds/license',
            File.read(license_tarball),
            {
              'version' => 'fake-license-fingerprint',
              'blobstore_id' => 'fake-license-blobstore_id',
            }
          )
        end

        let(:release_manifest) do
          original_release_manifest.merge(
            'license' => {
              'version' => 'fake-license-version',
              'sha1' => Digest::SHA1.file(license_tarball).hexdigest,
              'fingerprint' => 'fake-license-fingerprint',
              'blobstore_id' => 'fake-license-blobstore_id'
            })
        end

        it 'copies license' do
          release_compiler.compile
          expect(list_tar_files(release_tarball_file)).to include('./license.tgz')
        end
      end
    end
  end
end
