Sequel.migration do
  change do
    if [:mysql2, :mysql].include?(adapter_scheme)

      alter_table(:packages) do
        drop_index :sha1
        set_column_type :sha1, String, size: 512
        add_index :sha1, name: 'packages_sha1_index'
      end

      alter_table(:templates) do
        drop_index :sha1
        set_column_type :sha1, String, size: 512
        add_index :sha1, name: 'templates_sha1_index'
      end

      alter_table(:compiled_packages) do
        set_column_type :sha1, String, size: 512
      end

      alter_table(:ephemeral_blobs) do
        set_column_type :sha1, String, size: 512
      end

      alter_table(:stemcells) do
        set_column_type :sha1, String, size: 512
      end

      indexes = indexes(:local_dns_blobs).select { |_, value| value.fetch(:columns) == [:blobstore_id, :sha1] }
      index_name = indexes.empty? ? 'blobstore_id_sha1_idx' : indexes.first.first

      alter_table(:local_dns_blobs) do
        drop_index nil, name: index_name
        set_column_type :sha1, String, size: 512
        add_index :blobstore_id, unique: true, name: 'blobstore_id_idx'
      end
    else
      indexes = indexes(:local_dns_blobs).select { |_, value| value.fetch(:columns) == [:blobstore_id, :sha1] }
      index_name = indexes.empty? ? 'blobstore_id_sha1_idx' : indexes.first.first

      alter_table(:local_dns_blobs) do
        drop_index(nil, name: index_name)
        add_index :blobstore_id, unique: true, name: 'blobstore_id_idx'
      end
    end
  end
end
