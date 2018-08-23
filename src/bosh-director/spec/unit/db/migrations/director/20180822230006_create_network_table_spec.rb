require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'create_managed_network_tables' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20180822230006_create_network_table.rb' }
    let(:created_at) { Time.now.utc }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {
        id: 42,
        name: 'fake_deployment',
      }

      db[:deployments] << {
        id: 28,
        name: 'fake_deployment_2',
      }
    end

    it 'creates all tables for managed networks' do
      DBSpecHelper.migrate(migration_file)

      db[:networks] << {
        name: 'test_network_1',
        type: 'manual',
        created_at: created_at,
      }

      record = db[:networks].first
      expect(record[:created_at]).to_not be_nil
      expect(record[:id]).to eq(1)
      expect(record[:name]).to eq('test_network_1')
      expect(record[:type]).to eq('manual')
      expect(record[:orphaned]).to eq(false)
      expect(record[:orphaned_at]).to be_nil

      db[:subnets] << {
        cid: 'subnetid-12345',
        name: 'subnet-1',
        cpi: 'vsphere',
        cloud_properties: '{"name": "subnet-name"}',
        network_id: 1,
        reserved: '["192.168.10.2", "192.168.10.3"]',
        range: '192.168.10.10/24',
        gateway: '192.168.10.1',
      }

      expect(db[:subnets].first).to eq(
        id: 1,
        cid: 'subnetid-12345',
        name: 'subnet-1',
        cpi: 'vsphere',
        cloud_properties: '{"name": "subnet-name"}',
        network_id: 1,
        range: '192.168.10.10/24',
        reserved: '["192.168.10.2", "192.168.10.3"]',
        gateway: '192.168.10.1',
      )

      db[:deployments_networks] << {
        deployment_id: 42,
        network_id: 1,
      }

      expect(db[:deployments_networks].first).to eq(
        deployment_id: 42,
        network_id: 1,
      )
    end
  end
end
