require 'db_spec_helper'

module Bosh::Director
  describe 'Migrations Test Suite' do
    before do
      FileUtils.rm_rf('migrations-tmp')
      DBSpecHelper.reset_database
    end

    after do
      FileUtils.rm_rf('migrations-tmp')
    end

    it 'runs all migrations and retains data' do
      Sequel.extension :migration
      db = DBSpecHelper.db

      migrations_tmp_dir = FileUtils.mkdir('migrations-tmp')
      initial_migration = File.expand_path('../../../../db/migrations/director/20110209010747_initial.rb', __FILE__)
      FileUtils.cp(initial_migration, migrations_tmp_dir.first)
      Sequel::TimestampMigrator.new(db, migrations_tmp_dir.first, {}).run

      db[:releases] << {id: 1, name: 'db-migration-test-release'}
      db[:release_versions] << {id: 1, version: '1', release_id: 1}
      db[:deployments] << {id: 1, name: 'db-migration-test-deployment', manifest: '{"name": "db-migration-test-deployment", "release": {"version": "1", "name": "db-migration-test-release"}}', release_id: 1}
      db[:vms] << {id: 1, agent_id: 'db-migration-test-agent-id', cid: 'db-migration-test-cid', deployment_id: 1}
      db[:instances] << {id: 1, job: 'db-migration-test-job', index: 1, disk_cid: 'db-migration-test-disk-cid', deployment_id: 1, vm_id: 1}

      migrations_dir = File.expand_path('../../../../db/migrations/director/.', __FILE__)
      FileUtils.cp_r(migrations_dir, migrations_tmp_dir.first)
      Sequel::TimestampMigrator.new(db, "#{migrations_tmp_dir.first}/director", {}).run

      expect(db[:instances].count).to eq(1)
      expect(db[:instances].first).to include({id: 1, job: 'db-migration-test-job', index: 1, deployment_id: 1, vm_id: 1, state: 'started', resurrection_paused: nil, availability_zone: nil, cloud_properties: nil, compilation: false, bootstrap: false, dns_records: nil, spec_json: nil, vm_cid: 'db-migration-test-cid', agent_id: 'db-migration-test-agent-id', credentials_json: nil, trusted_certs_sha1: 'da39a3ee5e6b4b0d3255bfef95601890afd80709'})
      expect(db[:instances].first[:uuid]).not_to be_nil

      expect(db[:vms].count).to eq(1)
      expect(db[:vms].all).to include({id: 1, agent_id: 'db-migration-test-agent-id', cid: 'db-migration-test-cid', deployment_id: 1, credentials_json: nil, env_json: nil, trusted_certs_sha1: 'da39a3ee5e6b4b0d3255bfef95601890afd80709'})

      expect(db[:deployments].count).to eq(1)
      expect(db[:deployments].all).to include({id: 1, name: 'db-migration-test-deployment', manifest: '{"name": "db-migration-test-deployment", "release": {"version": "1", "name": "db-migration-test-release"}}', cloud_config_id: nil, link_spec_json: nil})
    end
  end
end
