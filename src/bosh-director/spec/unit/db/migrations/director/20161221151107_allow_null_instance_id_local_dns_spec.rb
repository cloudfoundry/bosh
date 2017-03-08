require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'allowing null instance_id in local_dns_records' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20161221151107_allow_null_instance_id_local_dns.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'allows instance_id to be null' do
      expect{
        db[:local_dns_records] << {id: 1, name: 'record1', ip: '123'}
      }.to raise_error Sequel::DatabaseError

      DBSpecHelper.migrate(migration_file)
      db[:local_dns_records] << {id: 1, name: 'record1', ip: '123'}
      expect(db[:local_dns_records].first[:instance_id]).to be_nil
    end
  end
end
