require 'spec_helper'

describe Bosh::Cli::ArchiveRepository do
  let(:archive_dir_path) { Pathname(Dir.mktmpdir) }
  let(:tarball) { Tempfile.new(['tarball', '.tgz']) }
  after { archive_dir_path.rmtree; tarball.unlink }
  let(:blobstore) { instance_double(Bosh::Blobstore::SimpleBlobstoreClient) }
  let(:resource) { instance_double(Bosh::Cli::Resources::Package, :name => 'package-name', :plural_type => 'packages') }
  let(:sha1) { 'sha1 for tarball' }

  subject(:archive_repository) { Bosh::Cli::ArchiveRepository.new(archive_dir_path.to_s, blobstore, resource) }

  describe '#copy_from_dev_to_final' do
    it 'creates a new BuildArtifact with updated tarball_path and dev_artifact?'
  end

  describe '#install' do
    let(:artifact) { Bosh::Cli::BuildArtifact.new('artifact-name', {'version' => fingerprint}, fingerprint, tarball.path, sha1, nil, true, !final) }
    let(:final_artifact_path) { archive_dir_path.join('.final_builds', 'packages', 'package-name') }
    let(:final_version_index) { Bosh::Cli::Versions::VersionsIndex.new(final_artifact_path.to_s) }
    let(:dev_artifact_path) { archive_dir_path.join('.dev_builds', 'packages', 'package-name') }
    let(:dev_version_index) { Bosh::Cli::Versions::VersionsIndex.new(dev_artifact_path.to_s) }
    let(:fingerprint) { 'the-fingerprint' }

    context 'when installing a dev artifact' do
      let(:final) { false }

      it 'places file in dev storage' do
        archive_repository.install(artifact)
        expect(dev_artifact_path.join("#{fingerprint}.tgz")).to exist
      end

      it 'adds file to dev index' do
        archive_repository.install(artifact)
        expect(dev_version_index[fingerprint]).to eq(
            "version" => "the-fingerprint",
            "sha1" => "da39a3ee5e6b4b0d3255bfef95601890afd80709",
          )
      end

      it 'returns a BuildArtifact with the new tarball path' do
        new_artifact = archive_repository.install(artifact)
        expect(new_artifact.tarball_path).to eq(dev_artifact_path.join("#{fingerprint}.tgz").to_s)
      end
    end

    context 'when installing a final artifact' do
      let(:final) { true }

      it 'places file in final storage' do
        archive_repository.install(artifact)
        expect(final_artifact_path.join("#{fingerprint}.tgz")).to exist
      end

      it 'adds file to final index' do
        archive_repository.install(artifact)
        expect(final_version_index[fingerprint]).to eq(
            "version" => "the-fingerprint",
            "sha1" => "da39a3ee5e6b4b0d3255bfef95601890afd80709",
          )
      end

      it 'returns a BuildArtifact with the new tarball path' do
        new_artifact = archive_repository.install(artifact)
        expect(new_artifact.tarball_path).to eq(final_artifact_path.join("#{fingerprint}.tgz").to_s)
      end
    end
  end
end
