require 'db_spec_helper'

module Bosh::Director
  describe 'add_errands' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170116235940_add_errand_runs.rb' }
    let(:instance) do
      {
        job: 'job',
        index: 1,
        deployment_id: 1,
        cloud_properties: 'cloud_properties',
        dns_records: 'dns_records',
        spec_json: 'spec_json',
        credentials_json: 'credentials_json',
        state: 'running'
      }
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {
        name: 'deployment_with_teams',
        link_spec_json: 'link_spec_json'
      }

      db[:instances] << instance
    end

    it 'creates the table with default value for ran_successfully' do
      DBSpecHelper.migrate(migration_file)
      db[:errand_runs] << {id: 1, instance_id: 1, successful_configuration_hash: 'some_hash', successful_packages_spec: 'long_json'}

      expect(db[:errand_runs].first[:instance_id]).to eq(1)
      expect(db[:errand_runs].first[:successful]).to be_falsey
      expect(db[:errand_runs].first[:successful_configuration_hash]).to eq('some_hash')
      expect(db[:errand_runs].first[:successful_packages_spec]).to eq('long_json')
    end

    it 'does not allow null values for instance' do
      DBSpecHelper.migrate(migration_file)
      expect {
        db[:errand_runs] << {id: 1}
      }.to raise_error Sequel::DatabaseError
    end
  end
end
