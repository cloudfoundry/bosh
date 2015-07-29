Sequel.migration do
  change do
    alter_table(:ip_addresses) do
      add_foreign_key :instance_id, :instances
      drop_column :deployment_id
    end
  end
end
