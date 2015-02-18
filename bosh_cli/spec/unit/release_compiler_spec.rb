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
    before do
      release_manifest = {
        'name' => 'fake-release-name',
        'version' => 'fake-release-version',
        'packages' => [{
          'name' => 'fake-package-name',
          'version' => 'fake-package-fingerprint',
          'sha1' => Digest::SHA1.file(package_tarball).hexdigest,
          'fingerpint' => 'fake-package-fingerprint',
          'blobstore_id' => 'fake-package-blobstore_id',
        }],
        'jobs' => [{
          'name' => 'fake-job-name',
          'version' => 'fake-job-fingerprint',
          'sha1' => Digest::SHA1.file(job_tarball).hexdigest,
          'fingerpint' => 'fake-job-fingerprint',
          'blobstore_id' => 'fake-job-blobstore_id',
        }],
        'license' => {
          'version' => 'fake-license-version',
          'sha1' => Digest::SHA1.file(license_tarball).hexdigest,
          'fingerprint' => 'fake-license-fingerprint',
          'blobstore_id' => 'fake-license-blobstore_id'
        }
      }

      File.write(release_manifest_file, YAML.dump(release_manifest))
    end

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

      release_source.add_version(
        'fake-job-fingerprint',
        '.final_builds/jobs/fake-job-name',
        File.read(job_tarball),
        {
          'version' => 'fake-job-fingerprint',
          'blobstore_id' => 'fake-job-blobstore_id',
        }
      )

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

    describe '#compile' do
      let(:release_tarball_file) { File.join(workspace_dir, 'fake-release-name-fake-release-version.tgz') }

      it 'copies packages' do
        release_compiler.compile
        expect(list_tar_files(release_tarball_file)).to include('./packages/fake-package-name.tgz')
      end

      it 'copies jobs' do
        release_compiler.compile
        expect(list_tar_files(release_tarball_file)).to include('./jobs/fake-job-name.tgz')
      end

      it 'copies license' do
        release_compiler.compile
        expect(list_tar_files(release_tarball_file)).to include('./license.tgz')
      end
    end
  end
end
