require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add historical metadata to orphaned vms' do
    let(:db) { DBSpecHelper.db }

    let(:migration_file) { '20180427184448_add_historical_metadata_to_orphaned_vms.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    it 'adds deployment_name and instance_name to orphaned_vms' do
      expect(db[:orphaned_vms].columns).to include(:deployment_name)
      expect(db[:orphaned_vms].columns).to include(:instance_name)
    end
  end
end
