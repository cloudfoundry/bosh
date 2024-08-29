require 'spec_helper'
require 'logger'
require 'bosh/director/models/package'

module Bosh::Director::Models
  describe Package do
    describe 'validations' do
      context 'when blobstore_id or sha1 are nil' do
        it 'should validate both sha1 and blobstore_id are nil' do
          expect do
            FactoryBot.create(:models_package, sha1: nil, blobstore_id: '1')
          end.to raise_error(Sequel::ValidationFailed, /sha1 presence/)

          expect do
            FactoryBot.create(:models_package, sha1: '1', blobstore_id: nil)
          end.to raise_error(Sequel::ValidationFailed, /blobstore_id presence/)

          expect do
            FactoryBot.create(:models_package, sha1: nil, blobstore_id: nil)
          end.to_not raise_error
        end
      end

      context 'when blobstore_id or sha1 are not nil' do
        it 'should validate both sha1 and blobstore_id are not nil' do
          expect do
            FactoryBot.create(:models_package, sha1: '11', blobstore_id: '22')
          end.to_not raise_error
        end
      end
    end

    describe 'contains_source?' do
      it 'is true if there is source in the blobstore' do
        expect(FactoryBot.create(:models_package, sha1: '1', blobstore_id: '22').source?).to eq true
      end

      it 'is false if there is not source in the blobstore' do
        expect(FactoryBot.create(:models_package, sha1: nil, blobstore_id: nil).source?).to eq false
      end
    end
  end
end
