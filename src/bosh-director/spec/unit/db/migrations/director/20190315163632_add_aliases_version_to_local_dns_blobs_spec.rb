require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190315163632_add_aliases_version_to_local_dns_blobs.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20190315163632_add_aliases_version_to_local_dns_blobs.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    context 'before migration' do
      it 'should NOT have aliases_version in local_dns_blobs' do
        expect(db[:local_dns_blobs].columns).to_not include(:aliases_version)
      end
    end

    context 'after migration' do
      before do
        DBSpecHelper.migrate(migration_file)
      end

      it 'should have aliases_version in local_dns_blobs' do
        expect(db[:local_dns_blobs].columns).to include(:aliases_version)
      end
    end
  end
end
