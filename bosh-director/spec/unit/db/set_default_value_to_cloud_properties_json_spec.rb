require 'db_spec_helper'

module Bosh::Director
  describe 'set default value to cloud properties json' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160223124032_set_default_value_to_cloud_properties_json.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }
    after { DBSpecHelper.reset_database }

    it 'runs set_value_to_cloud_properties_json migration' do
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

      db[:persistent_disks] << {

          instance_id: 1,
          disk_cid: 'fake-disk-cid',
          size: 50,
          active: true,
          cloud_properties_json: ''
      }
      expect(db[:persistent_disks].first[:cloud_properties_json]).to eq('')

      DBSpecHelper.migrate(migration_file)

      expect(db[:persistent_disks].first[:cloud_properties_json]).to eq('{}')

    end
  end
end