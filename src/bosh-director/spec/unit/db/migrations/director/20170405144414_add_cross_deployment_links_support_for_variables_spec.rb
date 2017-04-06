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
        db[:variables] << {id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200}

        DBSpecHelper.migrate(migration_file)
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
