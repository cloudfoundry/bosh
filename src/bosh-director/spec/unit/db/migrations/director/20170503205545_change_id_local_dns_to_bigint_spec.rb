require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'change id from int to bigint on local_dns_blob' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170503205545_change_id_local_dns_to_bigint.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    def can_insert_value_with_bigint(table, record, where_clause)
      db[table] << record
      expect(db[table].where(where_clause)).to_not be_empty
    end

    it 'increments id on local_dns_records from original series' do
      db[:local_dns_records] << {ip: '123'}
      former_max_id = db[:local_dns_records].all[-1][:id]

      DBSpecHelper.migrate(migration_file)

      db[:local_dns_records] << {ip: '456'}
      new_max_id = db[:local_dns_records].all[-1][:id]
      expect(new_max_id > former_max_id).to be_truthy
    end

    it 'local_dns_records should change the type from int to bigint' do
      if [:sqlite].include?(db.adapter_scheme)
        skip('Running using SQLite, wherein int == bigint')
      end

      expect {
        db[:local_dns_records] << {id: 8589934592, ip: '987'}

        # MariaDB does not error when inserting record, and instead just truncates records
        raise unless db[:local_dns_records].first[:id] == 8589934592
      }.to raise_error

      DBSpecHelper.migrate(migration_file)

      can_insert_value_with_bigint(:local_dns_records, {id: 9223372036854775807, ip: '123'}, Sequel.lit('id = 9223372036854775807'))
    end

    it 'increments id on local_dns_blobs from original series' do
      db[:local_dns_blobs] << {blobstore_id: '123', sha1: 'sha1', created_at: Time.now, version: 2}
      former_max_id = db[:local_dns_blobs].all[-1][:id]

      DBSpecHelper.migrate(migration_file)

      db[:local_dns_blobs] << {blobstore_id: '456', sha1: 'sha1', created_at: Time.now, version: 3}
      new_max_id = db[:local_dns_blobs].all[-1][:id]
      expect(new_max_id > former_max_id).to be_truthy
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
      can_insert_value_with_bigint(:local_dns_blobs, {id: 9223372036854775807, blobstore_id: '123', sha1: 'sha1', created_at: Time.now, version: 3}, Sequel.lit('id = 9223372036854775807'))
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
      can_insert_value_with_bigint(:local_dns_blobs, {version: 9223372036854775807, blobstore_id: '123', sha1: 'sha1', created_at: Time.now}, Sequel.lit('version = 9223372036854775807'))
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
      can_insert_value_with_bigint(:agent_dns_versions, {dns_version: 9223372036854775807, agent_id: '456'}, Sequel.lit('dns_version = 9223372036854775807'))
    end

    it 'increments id on agent_dns_versions from original series' do
      db[:agent_dns_versions] << {agent_id: '123', dns_version: 2}
      former_max_id = db[:agent_dns_versions].all[-1][:id]

      DBSpecHelper.migrate(migration_file)

      db[:agent_dns_versions] << {agent_id: '456', dns_version: 3}
      new_max_id = db[:agent_dns_versions].all[-1][:id]
      expect(new_max_id > former_max_id).to be_truthy
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
      can_insert_value_with_bigint(:agent_dns_versions, {id: 9223372036854775807, agent_id: '456', dns_version: 3}, Sequel.lit('id = 9223372036854775807'))
    end
  end
end


