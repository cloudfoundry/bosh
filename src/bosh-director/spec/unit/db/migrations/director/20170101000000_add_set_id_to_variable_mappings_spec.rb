require 'db_spec_helper'
require 'securerandom'

module Bosh::Director
  describe 'add_set_id_to_variable_mappings' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170124000000_add_set_id_to_variable_mappings.rb' }
    let(:set_id) { 'abc123' }
    let(:deployment_name) {'fake-deployment-name'}

    before {
      allow(SecureRandom).to receive(:uuid).and_return(set_id)

      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: deployment_name, manifest: '{}'}

      db[:vms] << {id: 1, agent_id: 'agent_id', deployment_id: 1}
      db[:instances] << {id: 1, deployment_id: 1, job: 'job_1', state: 'state', index: 0, vm_id: 1}

      DBSpecHelper.migrate(migration_file)
    }

    describe 'On update table' do
      it 'drops placeholder_mappings table' do
        expect(db.table_exists?(:placeholder_mappings)).to be_falsey
      end

      it 'adds variables_set_id column to deployments and instances table' do
        expect(db[:deployments].first[:variables_set_id]).to eq(deployment_name)
        expect(db[:instances].first[:variables_set_id]).to eq(deployment_name)

        expect(db[:deployments].count).to eq(1)
        expect(db[:instances].count).to eq(1)
      end

      it 'there is a unique constraint on set_id+variable_name' do
        db[:variable_mappings] << {id: 5, variable_id: '15', variable_name: 'variable_5', set_id: set_id}
        expect{
          db[:variable_mappings] << {id: 6, variable_id: '16', variable_name: 'variable_5', set_id: set_id}
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end
  end
end
