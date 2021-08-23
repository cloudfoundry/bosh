require 'db_spec_helper'

module Bosh::Director
  describe 'add cross deployment link support for variables' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170405144414_add_cross_deployment_links_support_for_variables.rb' }
    let(:mysql_db_adpater_schemes) { [:mysql, :mysql2] }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    describe 'alter variables table' do
      before do
        db[:deployments] << {id: 1, name: 'deployment_1'}
        db[:deployments] << {id: 2, name: 'deployment_2'}

        db[:variable_sets] << {id: 100, deployment_id: 1, created_at: Time.now}
        db[:variable_sets] << {id: 200, deployment_id: 2, created_at: Time.now}

        db[:variables] << {id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 100}
        db[:variables] << {id: 2, variable_id: 'var_id_2', variable_name: 'var_2', variable_set_id: 100}
        db[:variables] << {id: 3, variable_id: 'var[]_id_3', variable_name: 'var_3', variable_set_id: 200}

        DBSpecHelper.migrate(migration_file)

        expect(db[:variables].count).to eq(3)
      end

      it 'adds local boolean column and defaults it to true for existing variables' do
        db[:variables].each do |variable|
          expect(variable[:is_local]).to be_truthy
        end
      end

      it 'adds provider_deployment text column and defaults it to an empty string for existing variables' do
        db[:variables].each do |variable|
          expect(variable[:provider_deployment]).to be_empty
        end
      end

      it 'keeps the foreign key constraint with the variable set table' do
        expect {
          db[:variables] << {id: 999, variable_id: 'whatever', variable_name: 'another_whatever', variable_set_id: 999}
        }.to raise_error Sequel::ForeignKeyConstraintViolation

        expect {
          db[:variables] << {id: 999, variable_id: 'whatever', variable_name: 'another_whatever', variable_set_id: nil}
        }.to raise_error(/NOT NULL constraint failed: variables.variable_set_id/)

        expect {
          db[:variables] << {id: 999, variable_id: 'whatever', variable_name: 'another_whatever', variable_set_id: 100}
        }.to_not raise_error
      end

      it 'keeps correct foreign key constraints with variable set table after migration' do
        expect(db[:variables].where(id: 1).first[:variable_set_id]).to eq(100)
        expect(db[:variables].where(id: 2).first[:variable_set_id]).to eq(100)
        expect(db[:variables].where(id: 3).first[:variable_set_id]).to eq(200)
      end

      it 'keeps the cascade property when deleting variable sets' do
        db[:variable_sets].where(id: 100).delete

        expect(db[:variables].count).to eq(1)
        expect(db[:variables].where(variable_set_id: 100).count).to eq(0)
        expect(db[:variables].where(variable_set_id: 200).count).to eq(1)
      end

      it 'adds a new unique index for :variable_set_id, :variable_name, and :provider_deployment' do
        db[:variables] << {id: 5, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200, provider_deployment: 'test'}
        expect {
          db[:variables] << {id: 6, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200, provider_deployment: 'test'}
        }.to raise_error Sequel::UniqueConstraintViolation
      end

      it 'removes unique index :variable_set_id and :variable_name' do
        db[:variables] << {id: 5, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200, is_local: true, provider_deployment: 'some_deployment'}
        expect {
          db[:variables] << {id: 6, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200, is_local: true, provider_deployment: 'some_other_deployment'}
        }.to_not raise_error
      end
    end
  end
end
