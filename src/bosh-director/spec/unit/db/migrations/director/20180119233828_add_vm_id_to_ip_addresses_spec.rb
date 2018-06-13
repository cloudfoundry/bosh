require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add vm_id to ip_addresses' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20180119233828_add_vm_id_to_ip_addresses.rb' }
    let(:instance1) do
      {
        id: 123,
        availability_zone: 'z1',
        deployment_id: 1,
        job: 'instance_job',
        index: 23,
        state: 'started',
        variable_set_id: 57,
      }
    end

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << { id: 1, name: 'fake-deployment', manifest: '{}' }
      db[:variable_sets] << { id: 57, deployment_id: 1, created_at: Time.now }
      db[:instances] << instance1
      db[:vms] << { id: 1, instance_id: 123, active: true }
      db[:vms] << { id: 2, instance_id: 123, active: false }
      db[:ip_addresses] << { instance_id: 123, address_str: '10.0.0.1' }
      db[:ip_addresses] << { instance_id: 123, address_str: '10.1.0.1' }
    end

    it 'should add the vm_id column to ip_addresses table' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:ip_addresses].columns.include?(:vm_id)).to be_truthy
    end

    it 'should backfill vm_id of instances active vm on all up addresses' do
      DBSpecHelper.migrate(migration_file)

      db[:ip_addresses].each do |address|
        expect(address[:vm_id]).to eq(1)
      end
    end
  end
end
