require 'db_spec_helper'

module Bosh::Director
  describe 'Changing column type to longtext' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170119202003_update_sha1_column_sizes.rb' }
    let(:a_512_len_str) { 'b' * 512 }
    let(:a_255_len_str) { 'a' * 255 }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'updates the column type' do
      db[:releases] << {id: 1, name: 'test_release'}

      db[:packages] << {
        release_id: 1,
        name: 'test_package',
        version: 'abcd1234',
        dependency_set_json: '{}',
        sha1: (a_255_len_str),
      }

      db[:templates] << {
        name: 'template_name',
        release_id: 1,
        version: 'abcd1234',
        blobstore_id: '1',
        package_names_json: '{}',
        sha1: (a_255_len_str)
      }

      db[:compiled_packages] << {
        build: 1,
        package_id: 1,
        sha1: a_255_len_str,
        blobstore_id: '1234abcd',
        dependency_key: '{}',
        dependency_key_sha1: a_255_len_str,
      }

      db[:ephemeral_blobs] << {
        blobstore_id: '1',
        sha1: a_255_len_str,
        created_at: Time.now
      }

      db[:stemcells] << {
        name: 'stemcell_name',
        sha1: a_255_len_str,
        version: '1',
        cid: '1'
      }

      db[:local_dns_blobs] << {
        sha1: a_255_len_str,
        blobstore_id: 'blob_id',
        created_at: Time.now
      }

      indexes_before = {}
      db.tables.each do |t|
        indexes_before[t] = db.indexes(t)
      end

      DBSpecHelper.migrate(migration_file)

      expect(db[:packages].first[:sha1]).to eq(a_255_len_str)
      expect(db[:templates].first[:sha1]).to eq(a_255_len_str)
      expect(db[:compiled_packages].first[:sha1]).to eq(a_255_len_str)
      expect(db[:compiled_packages].first[:dependency_key_sha1]).to eq(a_255_len_str)
      expect(db[:ephemeral_blobs].first[:sha1]).to eq(a_255_len_str)
      expect(db[:stemcells].first[:sha1]).to eq(a_255_len_str)
      expect(db[:local_dns_blobs].first[:sha1]).to eq(a_255_len_str)

      db[:packages] << {
        release_id: 1,
        name: 'test_package',
        version: 'abcd1235',
        dependency_set_json: '{}',
        sha1: a_512_len_str,
      }
      expect(db[:packages].where(sha1: a_512_len_str).count).to eq(1)

      db[:templates] << {
        name: 'template_name',
        release_id: 1,
        version: 'abcd1235',
        blobstore_id: '1',
        package_names_json: '{}',
        sha1: a_512_len_str
      }
      expect(db[:templates].where(sha1: a_512_len_str).count).to eq(1)

      db[:compiled_packages] << {
        build: 1,
        package_id: 1,
        blobstore_id: '1234abcd',
        dependency_key: 'blarg',
        dependency_key_sha1: 'blarg_sha1',
        sha1: a_512_len_str
      }
      expect(db[:compiled_packages].where(sha1: a_512_len_str).count).to eq(1)

      db[:ephemeral_blobs] << {
        blobstore_id: '1',
        sha1: a_512_len_str,
        created_at: Time.now
      }
      expect(db[:ephemeral_blobs].where(sha1: a_512_len_str).count).to eq(1)

      db[:stemcells] << {
        name: 'stemcell_name',
        sha1: a_512_len_str,
        version: '2',
        cid: '1'
      }
      expect(db[:stemcells].where(sha1: a_512_len_str).count).to eq(1)

      db[:local_dns_blobs] << {
        sha1: 'c' * 512,
        blobstore_id: 'blob_id_2',
        created_at: Time.now
      }
      expect(db[:local_dns_blobs].where(sha1: 'c' * 512).count).to eq(1)

      db.tables.each do |t|
        if t == :local_dns_blobs
          expect(db.indexes(t)).to be_empty
        else
          expect(db.indexes(t)).to eq(indexes_before[t])
        end
      end
    end

    it 'migrates when the index is not present' do
      db.alter_table(:local_dns_blobs) do
        drop_index [:blobstore_id, :sha1], name: 'blobstore_id_sha1_idx'
      end

      db.tables.each do |t|
        if t == :local_dns_blobs
          expect(db.indexes(t)).to be_empty
        end
      end

      expect { DBSpecHelper.migrate(migration_file) }.to_not raise_exception

      db.tables.each do |t|
        if t == :local_dns_blobs
          expect(db.indexes(t)).to be_empty
        end
      end
    end
  end
end
