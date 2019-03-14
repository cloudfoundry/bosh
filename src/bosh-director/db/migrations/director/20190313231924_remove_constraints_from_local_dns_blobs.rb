Sequel.migration do
  up do
    alter_table(:local_dns_blobs) do
      set_column_allow_null(:blob_id)
      set_column_allow_null(:version)
      set_column_allow_null(:created_at)
    end
  end
end
