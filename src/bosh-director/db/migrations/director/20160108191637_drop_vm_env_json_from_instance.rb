Sequel.migration do
  change do
    alter_table(:instances) do
      drop_column :vm_env_json
    end
  end
end
