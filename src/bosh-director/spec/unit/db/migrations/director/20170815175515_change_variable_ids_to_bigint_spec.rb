require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'change id from int to bigint variable_sets & variables' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170815175515_change_variable_ids_to_bigint.rb' }
    let(:some_time) do
      Time.at(Time.now.to_i).utc
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: 'deployment_1'}
      db[:deployments] << {id: 2, name: 'deployment_5'}

    end

    def can_insert_value_with_bigint(table, record, where_clause)
      db[table] << record
      expect(db[table].where(where_clause)).to_not be_empty
    end

    describe 'variable_sets' do
      it 'does NOT impact existing data' do
        db[:variable_sets] << {deployment_id: 1, created_at: some_time}

        DBSpecHelper.migrate(migration_file)

        expect(db[:variable_sets].first).to include({:id=>1, :deployment_id=>1, :created_at=>some_time})
      end

      it 'continues auto incrementing ids from original series' do
        db[:variable_sets] << {deployment_id: 1, created_at: some_time}
        former_max_id = db[:variable_sets].all[-1][:id]

        DBSpecHelper.migrate(migration_file)

        db[:variable_sets] << {deployment_id: 2, created_at: some_time}
        new_max_id = db[:variable_sets].all[-1][:id]
        expect(new_max_id > former_max_id).to be_truthy
      end

      it 'variable_sets id should change the type from int to bigint' do
        if [:sqlite].include?(db.adapter_scheme)
          skip('Running using SQLite, wherein int == bigint')
        end

        expect {
          db[:variable_sets] << {id: 8589934592, deployment_id: 1, created_at: some_time}

          # MariaDB does not error when inserting record, and instead just truncates records
          raise unless db[:variable_sets].first[:id] == 8589934592
        }.to raise_error

        DBSpecHelper.migrate(migration_file)

        can_insert_value_with_bigint(:variable_sets, {id: 9223372036854775807, deployment_id: 2, created_at: some_time}, Sequel.lit('id = 9223372036854775807'))
      end

    end

    describe 'variables' do
      before do
        db[:variable_sets] << {id:1, deployment_id: 1, created_at: some_time}
        db[:variable_sets] << {id:2, deployment_id: 2, created_at: some_time}
      end

      it 'does NOT impact existing data' do
        db[:variables] << {variable_set_id: 1, variable_id: 'some_id', variable_name: 'some_name'}

        DBSpecHelper.migrate(migration_file)

        expect(db[:variables].first).to include({:id=>1, variable_set_id: 1, variable_id: 'some_id', variable_name: 'some_name'})
      end

      it 'continues auto incrementing ids from original series' do
        db[:variables] << {variable_set_id: 1, variable_id: 'some_id', variable_name: 'some_name'}
        former_max_id = db[:variables].all[-1][:id]

        DBSpecHelper.migrate(migration_file)

        db[:variables] << {variable_set_id: 2, variable_id: 'some_id_2', variable_name: 'some_name_2'}
        new_max_id = db[:variables].all[-1][:id]
        expect(new_max_id > former_max_id).to be_truthy
      end

      it 'variables id should change the type from int to bigint' do
        if [:sqlite].include?(db.adapter_scheme)
          skip('Running using SQLite, wherein int == bigint')
        end

        expect {
          db[:variables] << {id: 8589934592, variable_set_id: 1, variable_id: 'some_id', variable_name: 'some_name'}

          # MariaDB does not error when inserting record, and instead just truncates records
          raise unless db[:variables].first[:id] == 8589934592
        }.to raise_error

        DBSpecHelper.migrate(migration_file)

        can_insert_value_with_bigint(:variables, {id: 9223372036854775807, variable_set_id: 2, variable_id: 'some_id_2', variable_name: 'some_name_2'}, Sequel.lit('id = 9223372036854775807'))
      end

      it 'cascades on variable_sets deletion' do
        DBSpecHelper.migrate(migration_file)
        db[:variables] << {id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 1}
        db[:variables] << {id: 2, variable_id: 'var_id_2', variable_name: 'var_2', variable_set_id: 1}
        db[:variables] << {id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 2}

        expect(db[:variables].count).to eq(3)

        db[:variable_sets].where(id: 1).delete

        expect(db[:variables].count).to eq(1)
        expect(db[:variables].first).to include({id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 2})
      end

    end

  end
end


