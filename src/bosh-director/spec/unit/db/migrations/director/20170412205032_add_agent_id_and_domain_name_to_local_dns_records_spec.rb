require 'db_spec_helper'

module Bosh::Director
  describe 'add_agent_id_and_domain_name_to_local_dns_records_spec' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170412205032_add_agent_id_and_domain_name_to_local_dns_records.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      db[:deployments] << {id: 1, name: 'fake-deployment', manifest: '{}'}
      db[:variable_sets] << {deployment_id: 1, created_at: Time.now}
    end

    it 'ignores tombstones' do
      db[:local_dns_records] << {
        ip: 'd03b0d55-7a16-47d4-8eab-b1ebea8629cd-tombstone',
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:local_dns_records].first).to eq({
        id: 1,
        instance_id: nil,
        instance_group: nil,
        az: nil,
        network: nil,
        deployment: nil,
        ip: 'd03b0d55-7a16-47d4-8eab-b1ebea8629cd-tombstone',
        agent_id: nil,
        domain: nil,
      })
    end

    it 'ignores instances which do not currently have a vm' do
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

      db[:local_dns_records] << {
        instance_id: 1,
        instance_group: 'fake-instance-group',
        az: 'az1',
        network: 'fake-network',
        deployment: 'fake-deployment',
        ip: '192.168.0.1',
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:local_dns_records].first).to eq({
        id: 1,
        instance_id: 1,
        instance_group: 'fake-instance-group',
        az: 'az1',
        network: 'fake-network',
        deployment: 'fake-deployment',
        ip: '192.168.0.1',
        agent_id: nil,
        domain: nil,
      })
    end

    it 'adds domain name and agent id to the local_dns_records table' do
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

      db[:vms] << {
        id: 1,
        instance_id: 1,
        agent_id: 'fake-agent-uuid1',
        active: true,
      }

      db[:local_dns_records] << {
        instance_id: 1,
        instance_group: 'fake-instance-group',
        az: 'az1',
        network: 'fake-network',
        deployment: 'fake-deployment',
        ip: '192.168.0.1',
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:local_dns_records].first).to eq({
        id: 1,
        instance_id: 1,
        instance_group: 'fake-instance-group',
        az: 'az1',
        network: 'fake-network',
        deployment: 'fake-deployment',
        ip: '192.168.0.1',
        agent_id: 'fake-agent-uuid1',
        domain: nil,
      })
    end
  end
end
