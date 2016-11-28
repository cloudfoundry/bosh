Sequel.migration do
  change do
    alter_table(:deployments) do
      add_foreign_key :cloud_config_id, :cloud_configs
    end
  end
end
