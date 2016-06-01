Sequel.migration do
  up do
    create_table :local_dns_records do
      primary_key :id
      Time :timestamp, :index => true, :null => false
      # @todo should name+ip be unique?
      String :name, :unique => true, :null => false
      String :ip, :unique => false, :null => false
    end

    create_table :local_dns_blobs do
      primary_key :id
      String :blobstore_id, :null => false
      String :sha1, :null => false
      Time :created_at, null: false
    end
  end

  down do
    drop_table :local_dns_records
    drop_table :local_dns_blobs
  end
end
