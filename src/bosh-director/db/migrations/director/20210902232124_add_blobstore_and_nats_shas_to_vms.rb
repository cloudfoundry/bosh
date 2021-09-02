Sequel.migration do
  up do
    alter_table(:vms) do
      add_column :blobstore_config_sha1, String, size: 50
      add_column :nats_config_sha1, String, size: 50
    end
  end
end
