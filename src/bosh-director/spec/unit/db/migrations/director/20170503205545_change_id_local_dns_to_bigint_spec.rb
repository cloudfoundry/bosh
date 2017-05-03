require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'change id from int to bigint on local_dns_blob' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170503205545_change_id_local_dns_to_bigint.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'local_dns_records should change the type from int to bigint' do
      if [:sqlite].include?(db.adapter_scheme)
        skip('Running using SQLite, wherein int == bigint')
      end

      expect {
        db[:local_dns_records] << {id: 8589934592, ip: '123'}

        # MariaDB does not error when inserting record, and instead just truncates records
        raise unless db[:local_dns_records].first[:id] == 8589934592
      }.to raise_error

      DBSpecHelper.migrate(migration_file)
      db[:local_dns_records] << {id: 9223372036854775807, ip: '123'}
      expect(db[:local_dns_records].where('id = 9223372036854775807')).to_not be_nil
      end

    it 'local_dns_blobs should change the type of id from int to bigint' do
      if [:sqlite].include?(db.adapter_scheme)
        skip('Running using SQLite, wherein int == bigint')
      end

      expect {
        db[:local_dns_blobs] << {id: 8589934592, blobstore_id: '123', sha1: 'sha1', created_at: Time.now, version: 2}

        # MariaDB does not error when inserting record, and instead just truncates records
        raise unless db[:local_dns_blobs].first[:id] == 8589934592
      }.to raise_error

      DBSpecHelper.migrate(migration_file)
      db[:local_dns_blobs] << {id: 9223372036854775807, blobstore_id: '123', sha1: 'sha1', created_at: Time.now, version: 3}
      expect(db[:local_dns_blobs].where('id = 9223372036854775807')).to_not be_nil
    end

    it 'local_dns_blobs should change the type of version from int to bigint' do
      if [:sqlite].include?(db.adapter_scheme)
        skip('Running using SQLite, wherein int == bigint')
      end

      expect {
        db[:local_dns_blobs] << {version: 8589934592, blobstore_id: '123', sha1: 'sha1', created_at: Time.now}

        # MariaDB does not error when inserting record, and instead just truncates records
        raise unless db[:local_dns_blobs].first[:version] == 8589934592
      }.to raise_error

      DBSpecHelper.migrate(migration_file)
      db[:local_dns_blobs] << {version: 9223372036854775807, blobstore_id: '123', sha1: 'sha1', created_at: Time.now}
      expect(db[:local_dns_blobs].where('version = 9223372036854775807')).to_not be_nil
    end

    it 'agent_dns_versions should change the type of dns_version from int to bigint' do
      if [:sqlite].include?(db.adapter_scheme)
        skip('Running using SQLite, wherein int == bigint')
      end

      expect {
        db[:agent_dns_versions] << {dns_version: 8589934592, agent_id: '123'}

        # MariaDB does not error when inserting record, and instead just truncates records
        raise unless db[:agent_dns_versions].first[:dns_version] == 8589934592
      }.to raise_error

      DBSpecHelper.migrate(migration_file)
      db[:agent_dns_versions] << {dns_version: 9223372036854775807, agent_id: '456'}
      expect(db[:agent_dns_versions].where('dns_version = 9223372036854775807')).to_not be_nil
    end

    it 'agent_dns_versions should change the type of id from int to bigint' do
      if [:sqlite].include?(db.adapter_scheme)
        skip('Running using SQLite, wherein int == bigint')
      end

      expect {
        db[:agent_dns_versions] << {id: 8589934592, agent_id: '123', dns_version: 2}

        # MariaDB does not error when inserting record, and instead just truncates records
        raise unless db[:agent_dns_versions].first[:id] == 8589934592
      }.to raise_error

      DBSpecHelper.migrate(migration_file)
      db[:agent_dns_versions] << {id: 9223372036854775807, agent_id: '456', dns_version: 3}
      expect(db[:agent_dns_versions].where('id = 9223372036854775807')).to_not be_nil
    end
  end
end


