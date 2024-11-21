require 'spec_helper'

module Bosh::Director
  describe 'MySQL column types' do
    let(:db) { Bosh::Director::Config.db }

    let(:sequel_internal_tables) { [:schema_migrations] }
    let(:bosh_tables) { (db.tables - sequel_internal_tables) }

    before do
      skip('Skipping specs for `longtext` fields in MySQL') unless [:mysql2].include?(db.adapter_scheme)
    end

    it 'should use `longtext`' do
      bosh_tables.each do |table|
        db.schema(table).each do |column|
          column_name = column.first
          column_data = column.last
          column_type = column_data.fetch(:db_type)
          expect(column_type).to_not(
            eq('text'),
            "#{table}.#{column_name} (#{column_data.inspect}) type is `#{column_type}`, which has size limitations, use `longtext` instead",
          )
        end
      end
    end
  end
end
