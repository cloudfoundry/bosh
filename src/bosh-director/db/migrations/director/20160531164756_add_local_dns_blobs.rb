Sequel.migration do
  up do
    create_table :local_dns_blobs do
      primary_key :id
      String :blobstore_id, :null => false
      String :sha1, :null => false
      Time :created_at, null: false
    end

    alter_table :local_dns_blobs do
      add_index [:blobstore_id, :sha1], unique: true, name: 'blobstore_id_sha1_idx'
    end
  end

  down do
    drop_table :local_dns_blobs
  end
end
