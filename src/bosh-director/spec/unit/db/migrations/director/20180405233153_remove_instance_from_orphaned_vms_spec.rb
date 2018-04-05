require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180405233153_remove_instance_from_orphaned_vms.rb' do
    let(:db) {DBSpecHelper.db}

    before do
      DBSpecHelper.migrate_all_before(subject)
    end

    it 'remove instance column from orphaned_vms table' do
      expect(db[:orphaned_vms].columns.include?(:instance_id)).to be_truthy
      DBSpecHelper.migrate(subject)
      expect(db[:orphaned_vms].columns.include?(:instance_id)).to be_falsey
    end
  end
end
