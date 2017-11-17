require 'db_spec_helper'

module Bosh::Director
  describe 'add_variables' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170203212124_add_variables.rb' }
    let(:mysql_db_adpater_schemes) { [:mysql, :mysql2] }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    describe 'variable_sets table' do
      before do
        db[:deployments] << {id: 1, name: 'deployment_1'}
        db[:deployments] << {id: 2, name: 'deployment_2'}

        DBSpecHelper.migrate(migration_file)
      end

      it 'has a non null constraint for deployment_id' do
        expect {
          db[:variable_sets] << {id: 100, created_at: Time.now}
        }.to raise_error
      end

      it 'has a non null constraint for created_at' do
        if mysql_db_adpater_schemes.include?(db.adapter_scheme)
          skip('MYSQL v5.5.x running on CI + Ruby Sequel does NOT generate NULL constraint violations')
        end

        expect {
          db[:variable_sets] << {id: 100, deployment_id: 1}
        }.to raise_error
      end

      it 'defaults deploy_success to false' do
          db[:variable_sets] << {id: 100, deployment_id: 1, created_at: Time.now}
          expect(db[:variable_sets].first['deploy_success']).to be_falsey
      end

      it 'has a foreign key association with deployments table' do
        expect {
          db[:variable_sets] << {id: 100, deployment_id: 646464, created_at: Time.now}
        }.to raise_error Sequel::ForeignKeyConstraintViolation
      end

      it 'cascades on deployment deletion' do
        set_3_time = Time.now

        db[:variable_sets] << {id: 100, deployment_id: 1, created_at: Time.now}
        db[:variable_sets] << {id: 200, deployment_id: 1, created_at: Time.now}
        db[:variable_sets] << {id: 300, deployment_id: 2, created_at: set_3_time}

        expect(db[:variable_sets].count).to eq(5) # 2 were added during migration

        db[:deployments].where(id: 1).delete
        expect(db[:variable_sets].count).to eq(2)
        expect(db[:variable_sets].where(deployment_id: 1).count).to eq(0)
        expect(db[:variable_sets].where(deployment_id: 2).count).to eq(2)
      end
    end

    describe 'variables table' do
      before do
        db[:deployments] << {id: 1, name: 'deployment_1'}
        db[:deployments] << {id: 2, name: 'deployment_2'}

        DBSpecHelper.migrate(migration_file)

        db[:variable_sets] << {id: 100, deployment_id: 1, created_at: Time.now}
        db[:variable_sets] << {id: 200, deployment_id: 1, created_at: Time.now}
        db[:variable_sets] << {id: 300, deployment_id: 2, created_at: Time.now}
      end

      it 'has a non null constraint for variable_id' do
        if mysql_db_adpater_schemes.include?(db.adapter_scheme)
          skip('MYSQL v5.5.x running on CI + Ruby Sequel does NOT generate NULL constraint violations')
        end

        expect {
          db[:variables] << {id: 1, variable_name: 'var_1', variable_set_id: 100}
        }.to raise_error
      end

      it 'has a non null constraint for variable_name' do
        if mysql_db_adpater_schemes.include?(db.adapter_scheme)
          skip('MYSQL v5.5.x running on CI + Ruby Sequel does NOT generate NULL constraint violations')
        end

        expect {
          db[:variables] << {id: 1, variable_id: 'var_id_1', variable_set_id: 100}
        }.to raise_error
      end

      it 'has a non null constraint for variable_set_id' do
        expect {
          db[:variables] << {id: 1, variable_id: 'var_id_1', variable_name: 'var_1'}
        }.to raise_error
      end

      it 'cascades on variable_sets deletion' do
        db[:variables] << {id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 100}
        db[:variables] << {id: 2, variable_id: 'var_id_2', variable_name: 'var_2', variable_set_id: 100}
        db[:variables] << {id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200}

        expect(db[:variables].count).to eq(3)

        db[:variable_sets].where(id: 100).delete

        expect(db[:variables].count).to eq(1)
        expect(db[:variables].first).to eq({id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200})
      end

      it 'cascades on deployment deletion' do
        db[:variables] << {id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 100}
        db[:variables] << {id: 2, variable_id: 'var_id_2', variable_name: 'var_2', variable_set_id: 100}
        db[:variables] << {id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 300}

        expect(db[:variables].count).to eq(3)

        db[:deployments].where(id: 1).delete

        expect(db[:variables].count).to eq(1)
        expect(db[:variables].where(variable_set_id: 300).count).to eq(1)
      end

      it 'has variable_set_id and variable_name unique constraint' do
        db[:variables] << {id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 100}

        expect {
          db[:variables] << {id: 2, variable_id: 'var_id_2', variable_name: 'var_1', variable_set_id: 100}
        }.to raise_error Sequel::UniqueConstraintViolation
      end
    end

    describe 'adding variable sets to deployments' do
      before do
        db[:deployments] << {id: 123, name: 'deployment_1'}
      end

      it 'adds a variable set to deployment' do
        DBSpecHelper.migrate(migration_file)

        expect(db[:variable_sets].count).to eq(1)
        expect(db[:variable_sets].first[:deployment_id]).to eq(123)
        expect(db[:variable_sets].first[:created_at]).to_not be_nil
      end

    end

    describe 'instances table' do
      let(:instance_1) do
        {
          job: 'job_1',
          index: 1,
          deployment_id: 1,
          state: 'running'
        }
      end

      let(:instance_2) do
        {
          job: 'job_2',
          index: 1,
          deployment_id: 2,
          state: 'running'
        }
      end

      let(:instance_3) do
        {
          job: 'job_3',
          index: 2,
          deployment_id: 2,
          state: 'running'
        }
      end

      before do
        db[:deployments] << {id: 1, name: 'deployment_1'}
        db[:deployments] << {id: 2, name: 'deployment_2'}
        db[:deployments] << {id: 3, name: 'deployment_3'}
      end

      it 'fills foreign key variable_set_id in instances table' do
        db[:instances] << instance_1
        db[:instances] << instance_2
        db[:instances] << instance_3
        DBSpecHelper.migrate(migration_file)

        expect(db[:instances].count).to eq(3)

        variable_set_1_id = db[:variable_sets].where(deployment_id: 1).first[:id]
        dep_1_instances = db[:instances].where(deployment_id: 1).all
        expect(dep_1_instances.count).to eq(1)
        expect(dep_1_instances.first[:variable_set_id]).to eq(variable_set_1_id)

        variable_set_2_id = db[:variable_sets].where(deployment_id: 2).first[:id]
        dep_2_instances = db[:instances].where(deployment_id: 2).all
        expect(dep_2_instances.count).to eq(2)
        dep_2_instances.each do |instance|
          expect(instance[:variable_set_id]).to eq(variable_set_2_id)
        end

        dep_3_instances = db[:instances].where(deployment_id: 3).all
        expect(dep_3_instances.count).to eq(0)
      end

      it 'does not allow null for variable_set_id column' do
        DBSpecHelper.migrate(migration_file)
        expect {
          db[:instances] << {job: 'job', index: 1, deployment_id: 1, state: 'running'}
        }.to raise_error
      end

      it 'has a foreign key association with variable_sets table' do
        DBSpecHelper.migrate(migration_file)
        expect {
          db[:instances] << {job: 'job', index: 1, deployment_id: 1, state: 'running', variable_set_id: 999}
        }.to raise_error Sequel::ForeignKeyConstraintViolation
      end
    end
  end
end
