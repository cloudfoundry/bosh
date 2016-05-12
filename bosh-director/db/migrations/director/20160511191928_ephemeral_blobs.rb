Sequel.migration do
  change do
    adapter_scheme =  self.adapter_scheme

    create_table :ephemeral_blobs do
      primary_key :id

      if [:mysql2, :mysql].include?(adapter_scheme)
        longtext :blobstore_id, :null => false
        longtext :sha1, :null => false
      else
        text :blobstore_id, :null => false
        text :sha1, :null => false
      end

      Time :created_at, null: false
    end
  end
end
