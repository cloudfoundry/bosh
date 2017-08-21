require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'remove_unused_credentials_json_columns' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170821141953_remove_unused_credentials_json_columns.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    before do
      db[:deployments] << { name: 'fake-deployment', id: 1 }
      db[:variable_sets] << { id: 2, deployment_id: 1, created_at: Time.now }
      db[:instances] << { id: 3, availability_zone: 'z1', deployment_id: 1, job: 'instance_job', index: 0, state: 'started', variable_set_id: 2 }
    end

    it 'drops credentials_json_bak column from instances table' do
      expect(db[:instances].columns).to include(:credentials_json_bak)

      DBSpecHelper.migrate(migration_file)

      expect(db[:instances].columns).to_not include(:credentials_json_bak)
    end

    it 'drops credentials_json column from instances table' do
      expect(db[:vms].columns).to include(:credentials_json)

      DBSpecHelper.migrate(migration_file)

      expect(db[:vms].columns).to_not include(:credentials_json)
    end
  end
end
