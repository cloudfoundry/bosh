require 'db_spec_helper'

module Bosh::Director
  describe '20250623223600_add_dynamic_disks.rb' do
    let(:db) { DBSpecHelper.db }

    before { DBSpecHelper.migrate_all_before(subject) }

    it 'creates dynamic_disks table' do
      expect(db.table_exists?(:dynamic_disks)).to be_falsy

      DBSpecHelper.migrate(subject)

      expect(db.table_exists?(:dynamic_disks)).to be_truthy
      expect(db[:dynamic_disks].columns).to include(
        :id,
        :deployment_id,
        :disk_cid,
        :name,
        :disk_pool_name,
        :size,
        :metadata_json
      )
    end
  end
end
