require 'spec_helper'
require 'logger'
require 'bosh/director/models/package'

module Bosh::Director::Models
  describe Package do

    describe 'validations' do

      context 'when blobstore_id or sha1 are nil' do
        it "should validate both sha1 and blobstore_id are nil" do
           expect {
             described_class.make(sha1: nil, blobstore_id: '1', release_id: '1', name: 'pkg', version: '1', dependency_set_json: '[]')
           }.to raise_error(Sequel::ValidationFailed, /sha1 presence/)

           expect {
             described_class.make(sha1: '1', blobstore_id: nil, release_id: '1', name: 'pkg', version: '1', dependency_set_json: '[]')
           }.to raise_error(Sequel::ValidationFailed, /blobstore_id presence/)

           expect {
             described_class.make(sha1: nil, blobstore_id: nil, release_id: '1', name: 'pkg', version: '1', dependency_set_json: '[]')
           }.to_not raise_error
        end
      end

      context 'when blobstore_id or sha1 are not nil' do
        it 'should validate both sha1 and blobstore_id are not nil' do
          expect {
            described_class.make(sha1: '11', blobstore_id: '22', release_id: '1', name: 'pkg', version: '1', dependency_set_json: '[]')
          }.to_not raise_error
        end
      end

    end
  end
end

