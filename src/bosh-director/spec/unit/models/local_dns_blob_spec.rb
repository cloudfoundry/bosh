require 'spec_helper'

module Bosh::Director::Models
  describe LocalDnsBlob do
    describe '.latest' do
      it 'fetches the record with the latest version' do
        LocalDnsBlob.create(version: 1)
        LocalDnsBlob.create(version: 2)
        expected_blob = LocalDnsBlob.create(version: 1000)

        expect(LocalDnsBlob.latest).to eq(expected_blob)
      end

      # When the database constraints were removed from this table this became
      # possible if posting to the blobstore failed. Depending on the database,
      # records with the null version could be considered as newer than records
      # with an integer version.
      context 'when there is a record with a null version' do
        it 'ignores that record when fetching the latest record' do
          LocalDnsBlob.create(version: 1)
          LocalDnsBlob.create
          expected_blob = LocalDnsBlob.create(version: 1000)

          expect(LocalDnsBlob.latest).to eq(expected_blob)
        end
      end
    end
  end
end
