require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190318234554_add_criteria_columns_to_local_dns_aliases.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20190318234554_add_criteria_columns_to_local_dns_aliases.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    context 'before migration' do
      it 'should NOT have criteria columns in local_dns_aliases' do
        expect(db[:local_dns_aliases].columns).to_not include(:health_filter)
        expect(db[:local_dns_aliases].columns).to_not include(:placeholder_type)
        expect(db[:local_dns_aliases].columns).to_not include(:initial_health_check)
        expect(db[:local_dns_aliases].columns).to_not include(:group_id)
        expect(db[:local_dns_aliases].columns).to include(:target)
      end
    end

    context 'after migration' do
      before do
        DBSpecHelper.migrate(migration_file)
      end

      it 'should have criteria columns in local_dns_aliases' do
        expect(db[:local_dns_aliases].columns).to include(:health_filter)
        expect(db[:local_dns_aliases].columns).to include(:placeholder_type)
        expect(db[:local_dns_aliases].columns).to include(:initial_health_check)
        expect(db[:local_dns_aliases].columns).to include(:group_id)
        expect(db[:local_dns_aliases].columns).not_to include(:target)
      end
    end
  end
end
