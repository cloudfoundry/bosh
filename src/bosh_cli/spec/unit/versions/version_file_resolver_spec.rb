require 'spec_helper'

module Bosh::Cli::Versions
  describe VersionFileResolver do
    subject(:resolver) { VersionFileResolver.new(storage, blobstore) }
    let(:storage) { instance_double('Bosh::Cli::Versions::LocalArtifactStorage') }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }
    let(:tmp_dir) { Dir.mktmpdir }
    let(:desc) { 'fake-description' }

    after { FileUtils.rm_rf(tmp_dir) }

    describe '#find_file' do
      def self.it_attempts_to_download_from_blobstore
        context 'when the provided blobstore id is not nil' do
          let(:blobstore_id) { 'fake-blobstore-id' }
          let(:blobstore_file_sha1) { Digest::SHA1.hexdigest(blobstore_file_content) }
          let(:blobstore_file_content) { 'fake-blobstore-file-contents' }

          context 'when the file is in the blobstore' do
            before do
              allow(blobstore).to receive(:get).with(blobstore_id, anything, sha1: blobstore_file_sha1) do |blobstore_id, dest_file|
                dest_file.write(blobstore_file_content)
              end
            end

            context 'when the sha1 of the blobstore file matches the requested sha1' do
              it 'downloads the file form the blobstore and puts it in the storage' do
                expect(storage).to receive(:put_file).with(blobstore_file_sha1, anything).and_return('fake/storage/path')

                file_path = resolver.find_file(blobstore_id, blobstore_file_sha1, desc)
                expect(file_path).to eq('fake/storage/path')
              end
            end

            context 'when the blobstore raises an error' do
              let(:blobstore_file_sha1) { 'fake-non-matching-sha1' }
              let(:blobstore_error) { Bosh::Cli::BlobstoreError.new('sha1 mismatch') }

              before do
                allow(blobstore).to receive(:get).with(blobstore_id, anything, sha1: blobstore_file_sha1).
                  and_raise(blobstore_error)
              end

              it 'propagates that error' do
                expect {
                  resolver.find_file(blobstore_id, blobstore_file_sha1,desc)
                }.to raise_error(blobstore_error)
              end
            end
          end

          context 'when the file is not in the blobstore' do
            it 'raises an error' do
              expect(blobstore).to receive(:get).with(blobstore_id, anything, sha1: 'fake-non-matching-sha1') do
                raise 'file not in blobstore'
              end

              expect {
                resolver.find_file(blobstore_id, 'fake-non-matching-sha1', desc)
              }.to raise_error('file not in blobstore')
            end
          end
        end

        context 'when the provided blobstore id is nil' do
          let(:blobstore_id) { nil }

          it 'raises an error' do
            expect {
              resolver.find_file(blobstore_id, 'ignored-sha1', desc)
            }.to raise_error(
              "Cannot find #{desc}"
            )
          end
        end
      end

      context 'when the storage has the requested version file' do
        before do
          allow(storage).to receive(:has_file?).and_return(true)
          File.open(stored_file_path, 'w') { |f| f.write(storage_file_content) }
          allow(storage).to receive(:get_file).and_return(stored_file_path)
        end

        let(:stored_file_path) { File.join(tmp_dir, SecureRandom.uuid) }
        let(:storage_file_content) { 'fake-storage-file-contents' }
        let(:sha1) { Digest::SHA1.hexdigest(storage_file_content) }

        context 'when the sha1 of the stored file matches the requested sha1' do
          let(:blobstore_id) { nil }

          it 'returns the stored file path' do
            file_path = resolver.find_file(blobstore_id, sha1, desc)
            expect(file_path).to eq(stored_file_path)
          end
        end

        context 'when the sha1 of the stored file does not match the requested sha1' do
          it_attempts_to_download_from_blobstore
        end
      end

      context 'when the storage does not have the requested version file' do
        before { allow(storage).to receive(:has_file?).and_return(false) }

        it_attempts_to_download_from_blobstore
      end
    end

  end
end
