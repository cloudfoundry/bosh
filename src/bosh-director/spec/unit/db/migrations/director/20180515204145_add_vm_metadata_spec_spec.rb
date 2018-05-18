require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180515204145_add_vm_metadata_spec.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20180515204145_add_vm_metadata_spec.rb' }

    let(:spec_json) do
      JSON.dump(
        'stemcells' => {
          'name' => 'foostemcell',
          'version' => '1',
        },
        'networks' => { 'instance-networks' => %w[a b] },
        'env' => { 'some-env' => 'some-env-value' },
        'vm_type' => {
          'cloud_properties' => {
            'a' => 'b',
          },
        },
      )
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << { id: 1, name: 'fake-deployment', manifest: '{}' }
      db[:variable_sets] << { id: 57, deployment_id: 1, created_at: Time.now }
      db[:instances] << {
        id: 123,
        availability_zone: 'z1',
        deployment_id: 1,
        job: 'instance_job',
        index: 23,
        state: 'started',
        variable_set_id: 57,
        spec_json: spec_json,
      }
      db[:vms] << { instance_id: 123, active: true }
      db[:vms] << { instance_id: 123, active: false }
    end

    it 'backfills with values for instances where vm was active' do
      DBSpecHelper.migrate(migration_file)

      vms = db[:vms].all
      expect(vms[0][:stemcell_name]).to eq('foostemcell')
      expect(vms[1][:stemcell_name]).to eq('foostemcell')
      expect(vms[0][:stemcell_version]).to eq('1')
      expect(vms[1][:stemcell_version]).to eq('1')
      expect(vms[0][:env_json]).to eq(JSON.dump('some-env' => 'some-env-value'))
      expect(vms[1][:env_json]).to eq(JSON.dump('some-env' => 'some-env-value'))
      expect(vms[0][:cloud_properties_json]).to eq(JSON.dump('a' => 'b'))
      expect(vms[1][:cloud_properties_json]).to eq(JSON.dump('a' => 'b'))
    end

    it 'makes the env_json able to take long strings' do
      DBSpecHelper.migrate(migration_file)

      really_long_json_field = "{\"long-value\":\"#{'a' * 65_536}}\""
      db[:vms] << { instance_id: 123, env_json: really_long_json_field }
    end

    it 'makes the cloud_properties_json able to take long strings' do
      DBSpecHelper.migrate(migration_file)

      really_long_json_field = "{\"long-value\":\"#{'a' * 65_536}}\""
      db[:vms] << { instance_id: 123, cloud_properties_json: really_long_json_field }
    end

    it 'gracefully handles nil values' do
      db[:instances] << {
        id: 124,
        availability_zone: 'z1',
        deployment_id: 1,
        job: 'instance_job',
        index: 23,
        state: 'started',
        variable_set_id: 57,
        spec_json: nil,
      }
      db[:vms] << { instance_id: 124, active: true }
      db[:vms] << { instance_id: 124, active: false }

      DBSpecHelper.migrate(migration_file)
    end
  end
end
