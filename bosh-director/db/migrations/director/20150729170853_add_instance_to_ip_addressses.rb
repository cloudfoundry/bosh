Sequel.migration do
  change do
    alter_table(:ip_addresses) do
      add_foreign_key :instance_id, :instances
      drop_constraint :ip_addresses_deployment_id_fkey
      drop_column :deployment_id
    end
  end
end
