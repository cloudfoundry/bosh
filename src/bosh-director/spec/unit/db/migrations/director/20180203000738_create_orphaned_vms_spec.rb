require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180203000738_create_orphaned_vms.rb' do
    let(:db) { DBSpecHelper.db }

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    it 'creates a orphaned vms table' do
      DBSpecHelper.migrate(subject)

      db[:orphaned_vms] << {
        id: 1,
        availability_zone: 'potato',
        cid: 'asdf',
        cloud_properties: '{"foo":"bar"}',
        cpi: 'just-a-cpi',
        instance_id: 1,
        orphaned_at: Time.now,
      }
    end

    it 'adds a orphaned_vm_id column to the ip_addresses table' do
      DBSpecHelper.migrate(subject)

      expect(db[:ip_addresses].columns.include?(:orphaned_vm_id)).to be_truthy
    end
  end
end
