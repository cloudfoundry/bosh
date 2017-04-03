require 'db_spec_helper'

module Bosh::Director
  describe 'remove_active_vm_id_from_instances' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170331171657_remove_active_vm_id_from_instances.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'drops the active_vm_id from instances table' do
      expect(db[:instances].columns.include?(:active_vm_id)).to be_truthy

      DBSpecHelper.migrate(migration_file)
      expect(db[:instances].columns.include?(:active_vm_id)).to be_falsey
    end

    it 'adds is_active column to vms table' do
      expect(db[:vms].columns.include?(:active)).to be_falsey

      DBSpecHelper.migrate(migration_file)

      expect(db[:vms].columns.include?(:active)).to be_truthy
    end

    it 'sets all existing vms to be active true' do
      db[:vms] << {id: 1}

      DBSpecHelper.migrate(migration_file)

      expect(db[:vms].first[:active]).to eq(true)
    end

    it 'sets active to default to false' do
      DBSpecHelper.migrate(migration_file)

      db[:vms] << {id: 2}

      expect(db[:vms].first[:active]).to eq(false)
    end
  end
end
