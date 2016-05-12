require 'spec_helper'

module Bosh::Director
  module Jobs::Helpers
    describe EphemeralBlobDeleter do
      subject(:ephemeral_blob_deleter) { EphemeralBlobDeleter.new(blob_deleter, logger) }
      let(:blob_deleter) { BlobDeleter.new(blobstore, logger) }
      let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
      let(:ephemeral_blob_model) { Bosh::Director::Models::EphemeralBlob.new(blobstore_id: 'ephemeral_blob_id_1', sha1: 'smurf1').save }

      before do
        allow(blobstore).to receive(:delete)
      end

      describe 'deleting an ephemeral blob' do

        shared_examples_for 'removing an ephemeral blob' do
          it 'deletes the ephemeral blob' do
            expect(blobstore).to receive(:delete).with('ephemeral_blob_id_1')
            ephemeral_blob_deleter.delete(ephemeral_blob_model, force)
          end

          it 'destroys the ephemeralblob model' do
            ephemeral_blob_deleter.delete(ephemeral_blob_model, force)
            expect(Models::EphemeralBlob.all).to be_empty
          end

          it 'should have no errors' do
            expect(ephemeral_blob_deleter.delete(ephemeral_blob_model, force)).to be_empty
          end
        end

        describe 'when not forced', shared: true do
          let(:force) { false }

          include_examples 'removing an ephemeral blob'
        end

        describe 'when forced', shared: true do
          let(:force) { true }

          include_examples 'removing an ephemeral blob'

          context 'when deleting the blob fails' do
            before do
              allow(blobstore).to receive(:delete).and_raise('wont')
            end
            it 'destroys the template' do
              ephemeral_blob_deleter.delete(ephemeral_blob_model, force)
              expect(Models::EphemeralBlob.all).to be_empty
            end
          end
        end
      end
    end
  end
end
