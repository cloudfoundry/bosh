require 'db_spec_helper'

module Bosh::Director
  describe '20170320171505_add_id_group_az_network_deployment_columns_to_local_dns_records_spec' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170320171505_add_id_group_az_network_deployment_columns_to_local_dns_records.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'add the new columns' do
      db[:deployments] << {id: 1, name: 'fake-deployment', manifest: '{}'}
      db[:variable_sets] << {deployment_id: 1, created_at: Time.now}
      instance_spec_json_network = JSON.dump({
        'deployment' => 'fake-deployment',
        'networks' =>
          {
            'fake-network' => {'ip' => '192.168.0.1' },
            'other-network' => {'ip' => '192.168.1.2' }
          },
      })
      db[:instances] << {
        job: 'fake-instance-group',
        index: 1,
        deployment_id: 1,
        state: 'started',
        availability_zone: 'az1',
        variable_set_id: 1,
        spec_json: instance_spec_json_network,
      }
      instance_id = 1

      db[:local_dns_records] << {
        instance_id: instance_id,
        name: 'dns.record.name1',
        ip: '192.168.0.1',
      }

      db[:local_dns_records] << {
        instance_id: instance_id,
        name: 'dns.record.name2',
        ip: '192.168.1.2',
      }

      db[:local_dns_records] << {
        instance_id: nil,
        name: 'tombstone-record',
        ip: 'random-string',
      }

      db[:local_dns_records] << {
        instance_id: instance_id,
        name: 'dns.record.name2',
        ip: 'random-string',
      }
      
      DBSpecHelper.migrate(migration_file)

      expect(db[:local_dns_records].all).to contain_exactly(
        {
          id: 1,
          instance_id: instance_id,
          instance_group: 'fake-instance-group',
          name: 'dns.record.name1',
          az: 'az1',
          network: 'fake-network',
          deployment: 'fake-deployment',
          ip: '192.168.0.1',
        },
        {
          id: 2,
          instance_id: instance_id,
          instance_group: 'fake-instance-group',
          name: 'dns.record.name2',
          az: 'az1',
          network: 'other-network',
          deployment: 'fake-deployment',
          ip: '192.168.1.2',
        },
        {
          id: 3,
          instance_id: nil,
          instance_group: nil,
          name: 'tombstone-record',
          az: nil,
          network: nil,
          deployment: nil,
          ip: 'random-string',
        },
        {
          id: 4,
          instance_id: instance_id,
          instance_group: 'fake-instance-group',
          name: 'dns.record.name2',
          az: 'az1',
          network: '',
          deployment: 'fake-deployment',
          ip: 'random-string',
        },
      )

    end
  end
end
