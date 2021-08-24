require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190314192454_create_local_dns_aliases.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20190314192454_create_local_dns_aliases.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    context 'before migration' do
      it 'should NOT have a local_dns_aliases table' do
        expect { db[:local_dns_aliases] << {} }.to raise_error Sequel::DatabaseError
      end
    end

    context 'after migration' do
      before do
        DBSpecHelper.migrate(migration_file)
      end

      it 'should have a local_dns_aliases table' do
        expect { db[:local_dns_aliases] << {} }.not_to raise_error
      end
    end
  end
end
