require 'spec_helper'

module Bosh::Director
  describe 'validate mysql database' do
    let(:db) { Bosh::Director::Config.db }

    before do
      skip('Skipping tests that check for longtext fields in MySQL') unless [:mysql2, :mysql].include?(db.adapter_scheme)
    end

    it 'should only have longtext types' do
      excluded_tables = [:schema_migrations]
      (db.tables - excluded_tables).each do |table|
        db.schema(table).each do |column|
          expect(column.last[:db_type]).to_not eq('text'), "#{table}.#{column.first} is of type text.
Please consider migrating it to use longtext or add this table to excluded_tables"
        end
      end
    end

    context 'when the column name contains the string json' do
      it 'should be longtext type' do
        (db.tables).each do |table|
          db.schema(table).each do |column|
            column_name = column.first.to_s
            if column_name.include?('json')
              expect(column.last[:db_type]).to eq('longtext'), "#{table}.#{column.first} is not of type longtext."
            end
          end
        end
      end
    end
  end
end
