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

      index = indexes(:local_dns_blobs).detect { |name, _| name.to_s == 'blobstore_id_sha1_idx' }

      if !index.nil?
        alter_table(:local_dns_blobs) do
          drop_index(nil, name: 'blobstore_id_sha1_idx')
        end
      end

      alter_table(:local_dns_blobs) do
        set_column_type :sha1, String, size: 512
      end
    else
      index = indexes(:local_dns_blobs).detect { |name, _| name.to_s == 'blobstore_id_sha1_idx' }
      if !index.nil?
        alter_table(:local_dns_blobs) do
          drop_index(nil, name: 'blobstore_id_sha1_idx')
        end
      end
    end
  end
end
