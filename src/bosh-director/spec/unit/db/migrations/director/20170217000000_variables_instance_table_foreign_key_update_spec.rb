require 'db_spec_helper'

module Bosh::Director
  describe '20170217000000_variables_instance_table_foreign_key_update' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170217000000_variables_instance_table_foreign_key_update.rb' }
    let(:sqlite_adapter_scheme) { [:sqlite] }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    it 'drops [variable_set_id] fkey on instances and adds named fkey' do
      constraints = db.foreign_key_list(:instances).select do |v|
        v[:columns] == [:variable_set_id]
      end

      expect(constraints.size).to eq(1)
      constraint = constraints[0]
      expect(constraint[:columns]).to eq([:variable_set_id])
      expect(constraint[:table]).to eq(:variable_sets)

      if sqlite_adapter_scheme.include?(db.adapter_scheme)
        skip('sqlite doesnt show constraint name')
      end
        expect(constraint[:name]).to eq(:instance_table_variable_set_fkey)
        expect(constraint[:key]).to eq([:id])
    end
  end
end
