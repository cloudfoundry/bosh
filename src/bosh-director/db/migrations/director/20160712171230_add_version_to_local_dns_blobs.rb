Sequel.migration do
  change do
    alter_table(:local_dns_blobs) do
      add_column(:version, Integer)
    end
  end
end
