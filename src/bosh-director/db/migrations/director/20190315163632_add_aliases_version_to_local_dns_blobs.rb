Sequel.migration do
  up do
    alter_table(:local_dns_blobs) do
      add_column :aliases_version, Integer, null: false, default: 0
    end
  end
end
