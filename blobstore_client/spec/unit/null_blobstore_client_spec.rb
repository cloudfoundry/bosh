require 'spec_helper'
require 'blobstore_client/null_blobstore_client'

module Bosh::Blobstore
  describe NullBlobstoreClient do
    subject(:client) do
      NullBlobstoreClient.new
    end

    it_implements_base_client_interface

    describe '#create' do
      it 'does nothing' do
        expect {
          client.create('fake contents')
          client.create('fake contents', 'fake id')
        }.not_to raise_error
      end
    end
  end
end
