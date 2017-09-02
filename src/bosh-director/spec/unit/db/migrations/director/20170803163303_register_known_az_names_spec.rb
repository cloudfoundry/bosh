require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'register_known_az_names' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170803163303_register_known_az_names.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {
        name: 'deployment-1',
        id: 1,
      }
      db[:variable_sets] << {
        id: 15,
        deployment_id: 1,
        created_at: Time.now,
      }
    end

    def add_instance_to_az(az_name)
      db[:instances] << {
        availability_zone: az_name,
        index: 0,
        job: 'some-instance-group',
        deployment_id: 1,
        state: 'detached',
        variable_set_id: 15,
      }

      db[:local_dns_records] << {
        ip: 'somewhere',
        instance_id: db[:instances].max(:id),
      }
    end

    it 'inserts a record for every az name in dns records table and a dns tombstone' do
      add_instance_to_az('z1')
      add_instance_to_az('z2')
      add_instance_to_az('z2')

      expect {
        DBSpecHelper.migrate(migration_file)
      }.to change {
        db[:local_dns_records].max(:id)
      }.from(3).to(4)

      azs = db[:local_dns_encoded_azs].select(:name).all
      expect(azs).to contain_exactly(
        {name: 'z1'},
        {name: 'z2'},
      )
    end

    it 'does not attempt to register a null az' do
      add_instance_to_az('z1')
      add_instance_to_az(nil)
      add_instance_to_az(nil)

      DBSpecHelper.migrate(migration_file)

      azs = db[:local_dns_encoded_azs].select(:name).all
      expect(azs).to contain_exactly(
        {name: 'z1'},
      )
    end

    it 'does not insert tombstone if the local dns records table is empty' do
      expect(db[:local_dns_records].all.count).to eq 0

      expect {
        DBSpecHelper.migrate(migration_file)
      }.not_to change {
        db[:local_dns_records].all.count
      }
    end
  end
end
