require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'During migrations' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171117230219_add_network_spec_to_vms.rb'}
    let(:spec_json) { JSON.dump({'networks' => {'instance-networks' => ['a', 'b']}, 'and-ignored' => 'things'}) }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: 'fake-deployment', manifest: '{}'}
      db[:variable_sets] << {id: 57, deployment_id: 1, created_at: Time.now}
      db[:instances] << {id: 123, availability_zone: 'z1', deployment_id: 1, job: 'instance_job', index: 23, state: 'started', variable_set_id: 57, spec_json: spec_json}
      db[:vms] << {instance_id: 123, active: true}
      db[:vms] << {instance_id: 123, active: false}
    end

    it 'backfills with values for instances where vm was active' do
      DBSpecHelper.migrate(migration_file)

      vms = db[:vms].all
      vms.sort! { |vm1, vm2| vm1[:id] <=> vm2[:id] }
      expect(vms.length).to eq(2)
      expect(vms[0][:network_spec_json]).to eq(JSON.dump({'instance-networks' => ['a', 'b']}))
      expect(vms[1][:network_spec_json]).to eq(nil)
    end

    it 'makes the network_spec_json able to take long strings' do
      DBSpecHelper.migrate(migration_file)

      really_long_json_field = "{\"long-value\":\"#{'a' * 65536}}\""
      db[:vms] << {instance_id: 123, network_spec_json: really_long_json_field}
    end
  end
end
