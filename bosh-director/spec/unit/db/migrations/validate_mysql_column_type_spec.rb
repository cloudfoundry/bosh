require 'spec_helper'

module Bosh::Director
  describe 'validate mysql database' do
    let(:db) { Bosh::Director::Config.db }

    before do
      skip 'Skipping tests that check for longtext fields in MySQL' unless [:mysql2, :mysql].include?(db.adapter_scheme)
    end

    it 'should only have longtext types' do
      excluded_tables = [:schema_migrations, :vms]
      (db.tables - excluded_tables).each do |table|
        db.schema(table).each do |column|
          expect(column.last[:db_type]).not_to eq('text'), "#{table}.#{column.first} is of type text.
Please consider migrating it to use longtext or add this table to excluded_tables"
        end
      end
    end
  end
end
