require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'add subnet metadata to subnets' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20181024001616_add_subnet_metadata_to_subnets.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    it 'adds type, netmask_bits, and predeployment_cloud_properties to subnets' do
      expect(db[:subnets].columns).to include(:type)
      expect(db[:subnets].columns).to include(:predeployment_cloud_properties)
      expect(db[:subnets].columns).to include(:netmask_bits)
    end
  end
end
