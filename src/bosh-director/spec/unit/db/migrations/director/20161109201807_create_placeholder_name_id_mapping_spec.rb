require 'db_spec_helper'

module Bosh::Director

  describe 'create table for holding placeholder name to placeholder id mapping' do

    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161109201807_create_placeholder_name_id_mapping.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    context 'on upgrade' do

      before do
        expect(db.table_exists?(:placeholder_mappings)).to be_falsey
        DBSpecHelper.migrate(migration_file)
      end

      it 'should create table' do
        expect(db.table_exists?(:placeholder_mappings)).to be_truthy
      end
    end
  end
end
