require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'renames table' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170510190908_alter_ephemeral_blobs.rb' }
    let(:created_at_time) { Time.now.utc }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    context 'existing ephemeral blobs' do
      it 'increments id on local_dns_records from original series' do
        db[:ephemeral_blobs] << {blobstore_id: 'test1', sha1: 'fake-sha1', created_at: created_at_time}
        expect(db[:ephemeral_blobs].all.count).to eq(1)

        DBSpecHelper.migrate(migration_file)

        record = db[:blobs].all[0]
        expect(record[:blobstore_id]).to eq('test1')
        expect(record[:sha1]).to eq('fake-sha1')
        expect(record[:created_at]).to_not be_nil

        db[:blobs] << {blobstore_id: 'test2', sha1: 'fake-sha2', created_at: created_at_time}
        expect(db[:blobs].count).to eq(2)

        expect { db[:ephemeral_blobs].all }.to raise_exception(Sequel::DatabaseError)
      end

      it 'backfills ephemeral blobs as compiled releases' do
        db[:ephemeral_blobs] << {blobstore_id: 'test1', sha1: 'fake-sha1', created_at: created_at_time}
        expect(db[:ephemeral_blobs].all.count).to eq(1)

        DBSpecHelper.migrate(migration_file)

        record = db[:blobs].all[0]
        expect(record[:type]).to eq('compiled-release')
      end
    end

    context 'dns blobs' do
      it 'imports existing blobs' do
        db[:local_dns_blobs] << {blobstore_id: 'test1', sha1: 'fake-sha1', version: '2', created_at: created_at_time}
        pre_migration_record = db[:local_dns_blobs].all[0]

        DBSpecHelper.migrate(migration_file)

        post_migration_record = db[:blobs].all[0]
        expect(post_migration_record[:blobstore_id]).to eq(pre_migration_record[:blobstore_id])
        expect(post_migration_record[:sha1]).to eq(pre_migration_record[:sha1])
        expect(post_migration_record[:created_at]).to eq(pre_migration_record[:created_at])
        expect(post_migration_record[:type]).to eq('dns')

        post_migration_dns_blob = db[:local_dns_blobs].all[0]
        expect(post_migration_dns_blob[:blob_id]).to eq(post_migration_record[:id])

        # Dropping these columns, so hash lookup gives nil result
        expect(post_migration_dns_blob[:blobstore_id]).to be_nil
        expect(post_migration_dns_blob[:sha1]).to be_nil
      end

      it 'does not allow null blob_id' do
        DBSpecHelper.migrate(migration_file)

        expect { db[:local_dns_blobs] << {version: '2', created_at: created_at_time} }.to raise_error(/NOT NULL constraint failed: local_dns_blobs.blob_id/)
      end
    end
  end
end
