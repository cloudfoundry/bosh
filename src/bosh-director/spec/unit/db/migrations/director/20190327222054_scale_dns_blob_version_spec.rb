require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190327222054_scale_dns_blob_version.rb' do
    subject(:migration) { '20190327222054_scale_dns_blob_version.rb' }
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    context 'when adding new blob records' do
      before do
        db[:local_dns_blobs] << { version: 90 }
      end

      it 'makes it so new blob ids are greater than any version that existed before' do
        DBSpecHelper.migrate(subject)
        db[:local_dns_blobs] << {}
        expect(db[:local_dns_blobs].max(:id)).to be >= db[:local_dns_blobs].max(:version)
      end

      it 'does not change the number of rows in local_dns_blobs' do
        expect { DBSpecHelper.migrate(subject) }.not_to(change { db[:local_dns_blobs].count })
      end
    end

    context 'when migrating an empty db' do
      it 'does nothing' do
        expect { DBSpecHelper.migrate(subject) }.not_to(change { db[:local_dns_blobs].count })
      end
    end
  end
end
