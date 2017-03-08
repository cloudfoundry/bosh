require 'db_spec_helper'

module Bosh::Director
  describe 'Remove blobstore_id_idx' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170216194502_remove_blobstore_id_idx_from_local_dns_blobs.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'deletes it when it exists' do
      db.alter_table(:local_dns_blobs) do
        add_index :blobstore_id, unique: true, name: 'blobstore_id_idx'
      end

      expect(db.indexes(:local_dns_blobs)).to have_key(:blobstore_id_idx)
      DBSpecHelper.migrate(migration_file)
      expect(db.indexes(:local_dns_blobs)).to be_empty
    end

    it 'succeeds when it does not exist' do
      expect(db.indexes(:local_dns_blobs)).to_not have_key(:blobstore_id_idx)
      DBSpecHelper.migrate(migration_file)
      expect(db.indexes(:local_dns_blobs)).to be_empty
    end
  end
end
