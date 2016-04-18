require 'db_spec_helper'

module Bosh::Director
  describe 'set_instances_with_nil_serial_to_false' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160329201256_set_instances_with_nil_serial_to_false.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'updates instances\'s update properties "serial" from nil to false' do
      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}'}
      db[:instances] << {id: 1, job: 'fake-job', index: 1, deployment_id: 1, state: 'started'}
      db[:instances] << {
        id: 2,
        job: 'fake-job',
        index: 2,
        deployment_id: 1,
        state: 'started',
        spec_json: '{"update":{"serial":null}}'
      }
      db[:instances] << {
        id: 3,
        job: 'fake-job',
        index: 3,
        deployment_id: 1,
        state: 'started',
        spec_json: '{"update":{"serial":true}}'
      }
      db[:instances] << {
        id: 4,
        job: 'fake-job',
        index: 4,
        deployment_id: 1,
        state: 'started',
        spec_json: '{"update":{"serial":false}}'
      }
      db[:instances] << {
        id: 5,
        job: 'fake-job',
        index: 5,
        deployment_id: 1,
        state: 'started',
        spec_json: '{"update":{}}'
      }
      db[:instances] << {
        id: 6,
        job: 'fake-job',
        index: 6,
        deployment_id: 1,
        state: 'started',
        spec_json: '{}'
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:instances].count).to eq(6)
      instances = db[:instances].all
      expect(instances[0][:spec_json]).to be_nil
      expect(instances[1][:spec_json]).to eq('{"update":{"serial":false}}')
      expect(instances[2][:spec_json]).to eq('{"update":{"serial":true}}')
      expect(instances[3][:spec_json]).to eq('{"update":{"serial":false}}')
      expect(instances[4][:spec_json]).to eq('{"update":{}}')
      expect(instances[5][:spec_json]).to eq('{}')
    end
  end
end
