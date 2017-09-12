Sequel.migration do
  up do
    rename_table :ephemeral_blobs, :blobs

    alter_table(:blobs) do
      add_column :type, String
    end

    # technically there may be some local_dns blobs in here as well, but we'll use compiled-release because it has a
    # more restrictive retention policy and will clean up old entries more quickly
    self[:blobs].update(type: 'compiled-release')

    rename_table :local_dns_blobs, :local_dns_blobs_old

    create_table :local_dns_blobs do
      primary_key :id, :Bignum
      foreign_key :blob_id, :blobs, foreign_key_constraint_name: 'local_dns_blobs_blob_id_fkey', null: false
      Bignum :version, null: false
      Time :created_at, null: false
    end

    self[:local_dns_blobs_old].each do |blob|
      self[:blobs] << {
        blobstore_id: blob[:blobstore_id],
        sha1: blob[:sha1],
        created_at: blob[:created_at],
        type: 'dns',
      }

      self[:local_dns_blobs] << {
        id: blob[:id],
        blob_id: self[:blobs].where(blobstore_id: blob[:blobstore_id]).all[0][:id],
        version: blob[:version],
        created_at: blob[:created_at],
      }
    end

    drop_table :local_dns_blobs_old
  end
end
