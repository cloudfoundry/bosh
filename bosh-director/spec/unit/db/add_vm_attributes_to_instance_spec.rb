require 'db_spec_helper'

module Bosh::Director
  describe 'add_vm_attributes_to_instance' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20151229184742_add_vm_attributes_to_instance.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'runs drop_vm_env_json_from_instance migration and retains data' do
      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}'}
      db[:vms] << {
        id: 1,
        agent_id: 'fake-agent-id',
        cid: 'fake-vm-cid',
        env_json: 'fake-env-json',
        trusted_certs_sha1: 'fake-trusted-certs-sha1',
        credentials_json: 'fake-credentials-json',
        deployment_id: 1
      }
      db[:instances] << {id: 1, job: 'fake-job', index: 1, deployment_id: 1, vm_id: 1, state: 'started'}

      DBSpecHelper.migrate(migration_file)

      expect(db[:instances].count).to eq(1)
      expect(db[:instances].first[:vm_cid]).to eq('fake-vm-cid')
      expect(db[:instances].first[:agent_id]).to eq('fake-agent-id')
      expect(db[:instances].first[:vm_env_json]).to eq('fake-env-json')
      expect(db[:instances].first[:trusted_certs_sha1]).to eq('fake-trusted-certs-sha1')
      expect(db[:instances].first[:credentials_json]).to eq('fake-credentials-json')
    end
  end
end
