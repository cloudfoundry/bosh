require 'db_spec_helper'

module Bosh::Director
  describe '20170306215659_extend_vm_credentials_json_column_to_longtext' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170306215659_expand_vms_json_column_lengths.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'expands the column lengths' do
      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}'}
      attrs = {
          id: 1,
          deployment_id: 1,
          agent_id: 'fake-agent-id',
          cid: 'fake-vm-cid',
          env_json: 'fake-env-json',
          trusted_certs_sha1: 'fake-trusted-certs-sha1',
          credentials_json: 'fake-credentials-json'
      }
      db[:vms] << attrs

      DBSpecHelper.migrate(migration_file)

      expect(db[:vms].first).to eq(attrs)
    end
  end
end
