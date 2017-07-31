require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add_canonical_az_names_and_ids' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170628221611_add_canonical_az_names_and_ids.rb' }
    let(:created_at_time) { Time.now.utc }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}'}
      db[:variable_sets] << {id: 100, deployment_id: 1, created_at: Time.now}
      db[:instances] << {
        id: 1,
        job: 'fake-job',
        index: 1,
        availability_zone: 'z1',
        deployment_id: 1,
        variable_set_id: 100,
        state: 'started',
      }

      db[:instances] << {
        id: 2,
        job: 'fake-job',
        index: 2,
        availability_zone: 'z2',
        deployment_id: 1,
        variable_set_id: 100,
        state: 'started',
      }

      db[:instances] << {
        id: 3,
        job: 'fake-job',
        index: 3,
        availability_zone: nil,
        deployment_id: 1,
        variable_set_id: 100,
        state: 'started',
      }

      db[:instances] << {
        id: 4,
        job: 'fake-job',
        index: 4,
        availability_zone: 'z1',
        deployment_id: 1,
        variable_set_id: 100,
        state: 'started',
      }

      DBSpecHelper.migrate(migration_file)
    end

    it 'moves unique not-null AZ names from instances into a new table' do
      azs = db[:availability_zones].all

      expect(azs.count).to eq 2
      expect(azs[0][:name]).to eq 'z1'
      expect(azs[1][:name]).to eq 'z2'

      expect(azs[0][:id]).to eq 1
      expect(azs[1][:id]).to eq 2
    end

    it 'does not allow duplicate entries' do
      db[:availability_zones] << {name: 'something'}

      expect {
        db[:availability_zones] << {name: 'something'}
      }.to raise_error Sequel::UniqueConstraintViolation
    end

    it 'does not allow null entries' do
      expect {
        db[:availability_zones] << {name: nil}
      }.to raise_error Sequel::NotNullConstraintViolation
    end
  end
end
