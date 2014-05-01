require 'spec_helper'
require 'date'
require 'timecop'
require 'bosh/director/log_bundles_cleaner'

module Bosh::Director
  describe LogBundlesCleaner do
    subject(:log_bundles_cleaner) { described_class.new(blobstore, 86400, logger) } # 1 day
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient', delete: nil) }
    let(:logger) { Logger.new('/dev/null') }

    describe '#register_blobstore_id' do
      it 'keeps track of a log bundle associated with blobstore id' do
        expect {
          log_bundles_cleaner.register_blobstore_id('fake-blobstore-id')
        }.to change { Models::LogBundle.count }
        Models::LogBundle.filter(blobstore_id: 'fake-blobstore-id').count.should == 1
      end
    end

    describe '#clean' do
      before do
        Timecop.travel(Date.new(2011, 9, 1)) { log_bundles_cleaner.register_blobstore_id('fake-very-old-blob-id') }
        Timecop.travel(Date.new(2011, 10, 9)) { log_bundles_cleaner.register_blobstore_id('fake-old-blob-id') }
        Timecop.travel(Date.new(2011, 10, 10)) { log_bundles_cleaner.register_blobstore_id('fake-recent-blob-id') }
        Timecop.travel(Date.new(2011, 10, 11)) { log_bundles_cleaner.register_blobstore_id('fake-future-blob-id') }
      end

      before { Timecop.travel(Date.new(2011, 10, 10)) }
      after { Timecop.return }

      it 'deletes old log bundles from the database and keeps recent ones' do
        %w(fake-very-old-blob-id fake-old-blob-id fake-recent-blob-id fake-future-blob-id).each do |id|
          expect(Models::LogBundle.filter(blobstore_id: id).count).to eq(1)
        end

        log_bundles_cleaner.clean
        expect(Models::LogBundle.filter(blobstore_id: 'fake-very-old-blob-id').count).to eq(0)
        expect(Models::LogBundle.filter(blobstore_id: 'fake-old-blob-id').count).to eq(0)
        expect(Models::LogBundle.filter(blobstore_id: 'fake-recent-blob-id').count).to eq(1)
        expect(Models::LogBundle.filter(blobstore_id: 'fake-future-blob-id').count).to eq(1)
      end

      it 'deletes old log bundles from the blobstore and keeps recent ones' do
        expect(blobstore).to receive(:delete).with('fake-very-old-blob-id').and_return(true)
        expect(blobstore).to receive(:delete).with('fake-old-blob-id').and_return(true)
        expect(blobstore).to_not receive(:delete).with('fake-recent-blob-id')
        expect(blobstore).to_not receive(:delete).with('fake-future-blob-id')
        log_bundles_cleaner.clean
      end

      it 'keeps log bundle in the database if it fails to delete associated blob' do
        expect(blobstore).to receive(:delete).
           with('fake-very-old-blob-id').
           and_raise(Bosh::Blobstore::BlobstoreError)

        expect(blobstore).to receive(:delete).with('fake-old-blob-id').and_return(true)

        log_bundles_cleaner.clean
        expect(Models::LogBundle.filter(blobstore_id: 'fake-very-old-blob-id').count).to eq(1)
        expect(Models::LogBundle.filter(blobstore_id: 'fake-old-blob-id').count).to eq(0)
      end

      it 'deletes log bundle from the database if associated blob is not found' do
        expect(blobstore).to receive(:delete).
           with('fake-very-old-blob-id').
           and_raise(Bosh::Blobstore::NotFound)

        log_bundles_cleaner.clean
        expect(Models::LogBundle.filter(blobstore_id: 'fake-very-old-blob-id').count).to eq(0)
      end
    end
  end
end
