require 'spec_helper'
require 'blobstore_client/null_blobstore_client'

module Bosh::Blobstore
  describe NullBlobstoreClient do
    subject(:client) { described_class.new }

    it_implements_base_client_interface

    describe '#create' do
      it 'always returns random uuid' do
        id = subject.create('fake-contents')
        expect(id).to be_an_instance_of(String)
        expect(id.size).to be >= 1
      end
    end

    describe '#get' do
      it 'always raises NotFound error' do
        expect {
          subject.get('fake-id')
        }.to raise_error(NotFound, /fake-id/)
      end
    end

    describe '#delete' do
      it 'always returns nil' do
        expect(subject.delete('fake-id')).to be_nil
      end
    end

    describe '#exists?' do
      it 'always returns false' do
        expect(subject.exists?('fake-id')).to be(false)
      end
    end
  end
end
