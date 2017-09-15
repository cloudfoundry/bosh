Sequel.migration do
  up do
    self[:errand_runs].delete

    adapter_scheme =  self.adapter_scheme

    alter_table(:errand_runs) do
      drop_foreign_key :instance_id
      add_foreign_key :deployment_id, :deployments, :null => false, :on_delete => :cascade, default: -1
      add_column :errand_name, [:mysql2, :mysql].include?(adapter_scheme) ? 'longtext' : 'text'
      add_column :successful_state_hash, String, size: 512

      drop_column :successful_configuration_hash
      drop_column :successful_packages_spec
      drop_column :successful
    end
  end
end
