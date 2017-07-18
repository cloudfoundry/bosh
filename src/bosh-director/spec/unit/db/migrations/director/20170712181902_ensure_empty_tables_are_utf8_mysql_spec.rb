require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'ensuring empty tables are converted to UTF8' do
    let(:table_charset_query_for) do
      lambda do |table|
        %Q[
SELECT CCSA.character_set_name FROM information_schema.`TABLES` T,
       information_schema.`COLLATION_CHARACTER_SET_APPLICABILITY` CCSA
WHERE CCSA.collation_name = T.table_collation
AND T.table_name = "#{table}"
AND T.table_schema = (SELECT DATABASE());
      ]
      end
    end

    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170712181902_ensure_empty_tables_are_utf8_mysql.rb' }
    let(:table_name) { 'table_' + SecureRandom.uuid.gsub('-','') }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      skip 'Skipping tests that change table-specific charset in MySQL' unless [:mysql2, :mysql].include?(db.adapter_scheme)

      db.create_table table_name.to_sym, charset: 'latin1' do
        primary_key :id
        String :name
      end
    end

    it 'does not change the charset for tables that have contents' do
      db[table_name.to_sym] << {id: 1, name: 'entry'}

      DBSpecHelper.migrate(migration_file)

      query = table_charset_query_for.call(table_name)

      expect(db.fetch(query).first[:character_set_name]).to eq 'latin1'
    end

    it 'changes the charset for all tables that are empty' do
      DBSpecHelper.migrate(migration_file)

      query = table_charset_query_for.call(table_name)

      expect(db.fetch(query).first[:character_set_name]).to eq 'utf8mb4'
    end

    it 'converts the default character set to utf8mb4' do
      set_query = %Q[
ALTER DATABASE
  DEFAULT CHARACTER SET latin1;
]

      db.run(set_query)

      query = %Q[
SELECT default_character_set_name FROM information_schema.SCHEMATA
WHERE schema_name = (SELECT DATABASE());
]

      DBSpecHelper.migrate(migration_file)

      expect(db.fetch(query).first[:default_character_set_name]).to eq 'utf8mb4'

      db.create_table(('new' + table_name).to_sym) do
        primary_key :id
        String :name
      end

      query = table_charset_query_for.call('new' + table_name)

      expect(db.fetch(query).first[:character_set_name]).to eq 'utf8mb4'
    end
  end
end
