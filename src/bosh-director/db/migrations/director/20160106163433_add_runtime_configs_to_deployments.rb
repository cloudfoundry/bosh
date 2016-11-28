Sequel.migration do
  change do
    alter_table(:deployments) do
      add_foreign_key :runtime_config_id, :runtime_configs
    end
  end
end
