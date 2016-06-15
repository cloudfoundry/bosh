Sequel.migration do
  change do
    create_table :ephemeral_blobs do
      primary_key :id
      String :blobstore_id, :null => false
      String :sha1, :null => false
      Time :created_at, null: false
    end
  end
end
