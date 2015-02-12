require 'spec_helper'

describe Bosh::Cli::ArchiveRepository do
  let(:archive_dir_path) { Pathname(Dir.mktmpdir('bosh-archive-dir')) }
  let(:cache_dir_path) { Pathname(Dir.mktmpdir('bosh-cache-dir')) }
  let(:tarball) { Tempfile.new(['tarball', '.tgz']) }
  after { archive_dir_path.rmtree; cache_dir_path.rmtree; tarball.unlink }

  let(:blobstore) { instance_double(Bosh::Blobstore::SimpleBlobstoreClient) }
  let(:resource) { instance_double(Bosh::Cli::Resources::Package, :name => 'package-name', :plural_type => 'packages') }
  let(:sha1) { 'sha1 for tarball' }

  subject(:archive_repository) do
    Bosh::Cli::ArchiveRepository.new(archive_dir_path.to_s, cache_dir_path.to_s, blobstore, resource)
  end

  let(:artifact) { Bosh::Cli::BuildArtifact.new('artifact-name', fingerprint, tarball.path, sha1, nil, true, !final) }
  let(:artifact_path) { cache_dir_path.join("#{fingerprint}.tgz") }

  let(:final_version_index) do
    Bosh::Cli::Versions::VersionsIndex.new(
      archive_dir_path.join('.final_builds', 'packages', 'package-name')
    )
  end
  let(:dev_version_index) do
    Bosh::Cli::Versions::VersionsIndex.new(
      archive_dir_path.join('.dev_builds', 'packages', 'package-name')
    )
  end

  let(:fingerprint) { 'fake-fingerprint' }
  let(:final) { false }

  describe '#promote_from_dev_to_final' do
    it 'updates final index file with artifact fingerprint and sha1' do
      archive_repository.promote_from_dev_to_final(artifact)

      expect(final_version_index[fingerprint]).to eq(
          'version' => 'fake-fingerprint',
          'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
        )
    end

    it 'promotes artifact to final' do
      expect(artifact.dev_artifact?).to eq(true)
      archive_repository.promote_from_dev_to_final(artifact)
      expect(artifact.dev_artifact?).to eq(false)
    end
  end

  describe '#install' do
    context 'when installing a dev artifact' do
      let(:final) { false }

      it 'places file in cache storage' do
        archive_repository.install(artifact)
        expect(cache_dir_path.join("#{fingerprint}.tgz")).to exist
      end

      it 'adds file to dev index' do
        archive_repository.install(artifact)
        expect(dev_version_index[fingerprint]).to eq(
            'version' => 'fake-fingerprint',
            'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
          )
      end

      it 'returns a BuildArtifact with the new tarball path' do
        new_artifact = archive_repository.install(artifact)
        expect(new_artifact.tarball_path).to eq(artifact_path.to_s)
      end

      context 'when file is in dev index' do
        before do
          dev_version_index.add_version('fake-fingerprint', {
              'version' => 'fake-fingerprint',
              'sha1' => '289ecbf3fa7359e84d84e5d7c5edd22689ad81d4',
            })
        end

        it 'updates version with new sha' do
          archive_repository.install(artifact)
          dev_version_index.reload
          expect(dev_version_index[fingerprint]).to eq(
              'version' => 'fake-fingerprint',
              'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
            )
        end
      end

      context 'when file has blobstore_id' do
        before do
          dev_version_index.add_version('fake-fingerprint', {
              'version' => 'fake-fingerprint',
              'blobstore_id' => 'fake-blobstore-id',
            })
        end

        it 'raises an error' do
          expect { archive_repository.install(artifact) }.to raise_error /blobstore id/
        end
      end
    end

    context 'when installing a final artifact' do
      let(:final) { true }

      it 'places file in cache storage' do
        archive_repository.install(artifact)
        expect(cache_dir_path.join("#{fingerprint}.tgz")).to exist
      end

      it 'adds file to final index' do
        archive_repository.install(artifact)
        expect(final_version_index[fingerprint]).to eq(
            'version' => 'fake-fingerprint',
            'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
          )
      end

      it 'returns a BuildArtifact with the new tarball path' do
        new_artifact = archive_repository.install(artifact)
        expect(new_artifact.tarball_path).to eq(artifact_path.to_s)
      end

      context 'when file is in final index' do
        before do
          final_version_index.add_version('fake-fingerprint', {
              'version' => 'fake-fingerprint',
              'sha1' => '289ecbf3fa7359e84d84e5d7c5edd22689ad81d4',
            })
        end

        it 'updates version with new sha' do
          archive_repository.install(artifact)
          final_version_index.reload
          expect(final_version_index[fingerprint]).to eq(
              'version' => 'fake-fingerprint',
              'sha1' => 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
            )
        end
      end

      context 'when file has blobstore_id' do
        before do
          final_version_index.add_version('fake-fingerprint', {
              'version' => 'fake-fingerprint',
              'blobstore_id' => 'fake-blobstore-id',
            })
        end

        it 'raises an error' do
          expect { archive_repository.install(artifact) }.to raise_error /blobstore id/
        end
      end
    end
  end
end
