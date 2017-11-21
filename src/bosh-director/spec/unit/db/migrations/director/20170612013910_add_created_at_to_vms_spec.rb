require 'db_spec_helper'

module Bosh::Director
  describe 'Add created_at to vms table' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170612013910_add_created_at_to_vms.rb' }
    let(:created_at_time) { Time.now.utc }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      db[:deployments] << {id: 1, name: 'fake-deployment', manifest: '{}'}
      db[:variable_sets] << {deployment_id: 1, created_at: created_at_time}
      db[:instances] << {
        id: 1,
        job: 'fake-instance-group',
        uuid: 'uuid1',
        index: 1,
        deployment_id: 1,
        state: 'started',
        availability_zone: 'az1',
        variable_set_id: 1,
        spec_json: '{}',
      }
    end

    it 'adds the created_at column to the vms table and defaults it to nil' do
      db[:vms] << {
        id: 1,
        instance_id: 1,
        agent_id: 'fake-agent-uuid1',
        active: true
      }
      expect(db[:vms].columns.include?(:created_at)).to be_falsey
      DBSpecHelper.migrate(migration_file)
      expect(db[:vms].columns.include?(:created_at)).to be_truthy
      expect(db[:vms].where(id: 1).first[:created_at]).to be_nil
    end

    it 'supports adding created_at to vms' do
      DBSpecHelper.migrate(migration_file)
      db[:vms] << {
        id: 1,
        instance_id: 1,
        agent_id: 'fake-agent-uuid1',
        active: true,
        created_at: created_at_time
      }

      expect(db[:vms].where(id: 1).first[:created_at]).not_to be_nil
    end
  end
end
