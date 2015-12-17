require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe BlobDeleter do
      subject(:blob_deleter) { BlobDeleter.new(blobstore, logger) }
      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
      before { allow(blobstore).to receive(:delete) }
      let(:blob_id) { 'blob-id' }
      let(:errors) { [] }

      describe '#delete' do
        context 'when force false' do
          let(:force) { false }

          context 'when deletion is sucessful' do
            it 'deletes the blob from the blobstore' do
              expect(blobstore).to receive(:delete).with('blob-id')
              blob_deleter.delete(blob_id, errors, force)
            end

            it 'returns true' do
              expect(blob_deleter.delete(blob_id, errors, force)).to eq(true)
            end
          end

          context 'when deletion fails' do
            before { allow(blobstore).to receive(:delete).with('blob-id').and_raise('failed to delete') }

            it 'adds an error in to the errors array' do
              blob_deleter.delete(blob_id, errors, force)
              expect(errors.map(&:message)).to eq(['failed to delete'])
            end

            it 'returns true' do
              expect(blob_deleter.delete(blob_id, errors, force)).to eq(false)
            end
          end
        end

        context 'when force is true' do
          let(:force) { true }

          context 'when deletion is sucessful' do
            it 'deletes the blob from the blobstore' do
              expect(blobstore).to receive(:delete).with('blob-id')
              blob_deleter.delete(blob_id, errors, force)
            end

            it 'returns true' do
              expect(blob_deleter.delete(blob_id, errors, force)).to eq(true)
            end
          end

          context 'when deletion fails' do
            before { allow(blobstore).to receive(:delete).with('blob-id').and_raise('failed to delete') }

            it 'adds an error in to the errors array' do
              blob_deleter.delete(blob_id, errors, force)
              expect(errors.map(&:message)).to eq(['failed to delete'])
            end

            it 'returns true' do
              expect(blob_deleter.delete(blob_id, errors, force)).to eq(true)
            end
          end
        end
      end
    end
  end
end
