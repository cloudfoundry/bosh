Sequel.migration do
  up do
    alter_table(:local_dns_blobs) do
      add_column :records_version, Integer, null: false, default: 0
    end
  end
end
