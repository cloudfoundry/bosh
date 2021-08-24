require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190104135624_add_update_completed_to_release_versions.rb' do
    let(:migration_file) { '20190104135624_add_update_completed_to_release_versions.rb' }

    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:releases] << { name: 'rel1' }
      db[:releases] << { name: 'rel2' }
    end

    it 'defaults update_completed to true' do
      db[:release_versions] << { id: 100, version: 'ver1', release_id: 1, commit_hash: 'uuid-1', uncommitted_changes: false }
      db[:release_versions] << { id: 200, version: 'ver2', release_id: 2, commit_hash: 'uuid-2', uncommitted_changes: false }

      DBSpecHelper.migrate(migration_file)

      expect(db[:release_versions].columns).to include(:update_completed)

      expect(db[:release_versions].where(id: 100).first[:update_completed]).to eq(true)
      expect(db[:release_versions].where(id: 200).first[:update_completed]).to eq(true)
    end

    it 'add entries with optional update_completed and still defaults it to true' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:release_versions].columns).to include(:update_completed)

      db[:release_versions] << { id: 300, version: 'ver1', release_id: 1, commit_hash: 'uuid-1', uncommitted_changes: false, update_completed: true }
      db[:release_versions] << { id: 400, version: 'ver2', release_id: 2, commit_hash: 'uuid-2', uncommitted_changes: false }

      expect(db[:release_versions].where(id: 300).first[:update_completed]).to eq(true)
      expect(db[:release_versions].where(id: 400).first[:update_completed]).to eq(false)
    end

    it 'fail when adding null value for update_completed' do
      DBSpecHelper.migrate(migration_file)

      expect {
        db[:release_versions] << { id: 500, version: 'ver1', release_id: 1, commit_hash: 'uuid-1', uncommitted_changes: false, update_completed: nil }
      }.to raise_error Sequel::NotNullConstraintViolation
    end
  end
end
