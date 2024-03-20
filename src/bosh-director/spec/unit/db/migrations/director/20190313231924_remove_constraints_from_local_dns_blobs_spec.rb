require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20190313231924_remove_constraints_from_local_dns_blobs.rb' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20190313231924_remove_constraints_from_local_dns_blobs.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      db[:tasks] << { id: 1, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type' }
      db[:tasks] << { id: 2, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type' }
      db[:tasks] << { id: 3, state: 'alabama', timestamp: '2016-04-14 11:53:42', description: 'descr', type: 'type' }
    end

    context 'before migration' do
      it 'should NOT allow empty records in local_dns_blobs' do
        DBSpecHelper.skip_on_mysql(self, 'NULL constraint violations not generated')

        expect { db[:local_dns_blobs] << {} }.to raise_error Sequel::NotNullConstraintViolation
        expect(db[:local_dns_blobs].count).to eq(0)
      end
    end

    context 'after migration' do
      before do
        DBSpecHelper.migrate(migration_file)
      end

      it 'should allow empty records in local_dns_blobs' do
        expect { db[:local_dns_blobs] << {} }.not_to raise_error
        expect(db[:local_dns_blobs].count).to eq(1)
      end
    end
  end
end
