require 'db_spec_helper'

module Bosh::Director
  describe 'backfill_local_dns_records_and_drop_name' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170405181126_backfill_local_dns_records_and_drop_name.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      db[:deployments] << {id: 1, name: 'fake-deployment', manifest: '{}'}
      db[:variable_sets] << {deployment_id: 1, created_at: Time.now}
    end

    it 'drops the name from local_dns_records table and backfills data' do
      DBSpecHelper.skip_on_sqlite(self, 'auto-increment is not predictable')

      instance1_spec_json = JSON.dump(
          {
              'deployment' => 'fake-deployment',
              'networks' =>
                  {
                      'fake-network' => {'ip' => '192.168.0.1'},
                      'other-network' => {'ip' => '192.168.1.2'}
                  },
          }
      )
      db[:instances] << {
          job: 'fake-instance-group',
          uuid: 'uuid1',
          index: 1,
          deployment_id: 1,
          state: 'started',
          availability_zone: 'az1',
          variable_set_id: 1,
          spec_json: instance1_spec_json,
      }
      instance_id = 1

      db[:local_dns_records] << {
          instance_id: instance_id,
          instance_group: 'fake-instance-group',
          name: 'uuid1.fake-instance-group.fake-network.fake-deployment.name1',
          az: 'az1',
          network: 'fake-network',
          deployment: 'fake-deployment',
          ip: '192.168.0.1',
      }

      db[:local_dns_records] << {
          instance_id: instance_id,
          instance_group: 'fake-instance-group',
          name: '1.fake-instance-group.fake-network.fake-deployment.name1',
          az: 'az1',
          network: 'fake-network',
          deployment: 'fake-deployment',
          ip: '192.168.0.1',
      }

      db[:local_dns_records] << {
          instance_id: instance_id,
          instance_group: 'fake-instance-group',
          name: 'uuid1.fake-instance-group.other-network.fake-deployment.name1',
          az: 'az1',
          network: 'other-network',
          deployment: 'fake-deployment',
          ip: '192.168.1.2',
      }

      db[:local_dns_records] << {
          instance_id: instance_id,
          instance_group: 'fake-instance-group',
          name: '1.fake-instance-group.other-network.fake-deployment.name1',
          az: 'az1',
          network: 'other-network',
          deployment: 'fake-deployment',
          ip: '192.168.1.2',
      }

      instance2_spec_json = JSON.dump(
          {
              'deployment' => 'fake-deployment',
              'networks' =>
                  {
                      'fake-network' => {'ip' => '192.168.0.2'},
                      'other-network' => {'ip' => '192.168.1.3'}
                  },
          }
      )
      instance2_id = 2

      db[:instances] << {
          job: 'fake-instance-group',
          uuid: 'uuid2',
          index: 2,
          deployment_id: 1,
          state: 'started',
          availability_zone: 'az1',
          variable_set_id: 1,
          spec_json: instance2_spec_json,
      }

      db[:instances] << {
          job: 'fake-instance-group',
          uuid: 'uuid3',
          index: 3,
          deployment_id: 1,
          state: 'started',
          availability_zone: 'az1',
          variable_set_id: 1,
          spec_json: 'invalid json',
      }

      db[:instances] << {
          job: 'fake-instance-group',
          uuid: 'uuid4',
          index: 4,
          deployment_id: 1,
          state: 'started',
          availability_zone: 'az1',
          variable_set_id: 1,
          spec_json: JSON.dump(
          {
              'deployment' => 'fake-deployment',
              'networks' =>
                  {
                      'fake-network' => {'ip' => '192.168.5.2'},
                      'other-network' => nil
                  },
          })
      }

      db[:instances] << {
          job: 'fake-instance-group',
          uuid: 'uuid5',
          index: 5,
          deployment_id: 1,
          state: 'started',
          availability_zone: 'az1',
          variable_set_id: 1,
          spec_json: JSON.dump(
          {
              'deployment' => 'fake-deployment',
              'networks' => nil
          })
      }

      DBSpecHelper.migrate(migration_file)

      expect(db[:local_dns_records].all).to contain_exactly(
        {
            id: 5,
            instance_id: instance_id,
            instance_group: 'fake-instance-group',
            az: 'az1',
            network: 'fake-network',
            deployment: 'fake-deployment',
            ip: '192.168.0.1',
        },
        {
            id: 6,
            instance_id: instance_id,
            instance_group: 'fake-instance-group',
            az: 'az1',
            network: 'other-network',
            deployment: 'fake-deployment',
            ip: '192.168.1.2',
        },
        {
            id: 7,
            instance_id: instance2_id,
            instance_group: 'fake-instance-group',
            az: 'az1',
            network: 'fake-network',
            deployment: 'fake-deployment',
            ip: '192.168.0.2',
        },
        {
            id: 8,
            instance_id: instance2_id,
            instance_group: 'fake-instance-group',
            az: 'az1',
            network: 'other-network',
            deployment: 'fake-deployment',
            ip: '192.168.1.3',
        },
        {
            id: 9,
            instance_id: 4,
            instance_group: 'fake-instance-group',
            az: 'az1',
            network: 'fake-network',
            deployment: 'fake-deployment',
            ip: '192.168.5.2',
        }
      )
    end

    it 'drops the cascade delete so developers know to delete the local_dns_records properly, and ensuring tombstones' do
      instance1_spec_json = JSON.dump(
          {
              'deployment' => 'fake-deployment',
              'networks' =>
                  {
                      'fake-network' => {'ip' => '192.168.0.1'},
                      'other-network' => {'ip' => '192.168.1.2'}
                  },
          }
      )

      db[:instances] << {
          job: 'fake-instance-group',
          uuid: 'uuid1',
          index: 1,
          deployment_id: 1,
          state: 'started',
          availability_zone: 'az1',
          variable_set_id: 1,
          spec_json: instance1_spec_json,
      }

      DBSpecHelper.migrate(migration_file)

      expect{
        db[:instances].delete
      }.to raise_error(Sequel::ForeignKeyConstraintViolation)
    end
  end
end
