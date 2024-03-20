require 'db_spec_helper'

module Bosh::Director
  describe '20170217000000_variables_instance_table_foreign_key_update' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170217000000_variables_instance_table_foreign_key_update.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    let(:constraints) { db.foreign_key_list(:instances).select { |v| v[:columns] == [:variable_set_id] } }

    it 'drops [variable_set_id] fkey on instances and adds named fkey' do
      expect(constraints.size).to eq(1)

      expect(constraints[0][:columns]).to eq([:variable_set_id])
      expect(constraints[0][:table]).to eq(:variable_sets)
    end

    it 'adds named fkey' do
      DBSpecHelper.skip_on_sqlite(self, 'constraint name not shown')

      expect(constraints[0][:name]).to eq(:instance_table_variable_set_fkey)
      expect(constraints[0][:key]).to eq([:id])
    end
  end
end
