require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add_deployment_and_errand_name_to_errand_runs' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170804191205_add_deployment_and_errand_name_to_errand_runs.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    before do
      db[:deployments] << { name: 'fake-deployment', id: 42 }
      db[:variable_sets] << { id: 57, deployment_id: 42, created_at: Time.now }
      db[:instances] << { id: 123, availability_zone: 'z1', deployment_id: 42, job: 'instance_job', index: 23, state: 'started', variable_set_id: 57 }
      db[:errand_runs] << { id: 1, instance_id: 123 }
    end

    it 'deletes existing records' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:errand_runs].count).to eq(0)
    end

    it 'removes the instance_id column and adds deployment foreign key, errand name and leaves the configuration column' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:errand_runs].columns).to contain_exactly(:id, :successful_state_hash, :deployment_id, :errand_name)
    end

    it 'sets cascading deletion for deployment foreign key' do
      DBSpecHelper.migrate(migration_file)

      db[:errand_runs] << {id: 1, deployment_id: 42}

      db[:instances].delete
      db[:deployments].delete
      expect(db[:errand_runs].count).to eq(0)
    end

    it 'does not cause deletion of an errand run to delete associated deployment' do
      DBSpecHelper.migrate(migration_file)

      db[:errand_runs] << {id: 1, deployment_id: 42}

      db[:errand_runs].delete
      expect(db[:deployments].count).to eq(1)
    end
  end
end
