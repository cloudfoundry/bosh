Sequel.migration do
  change do
    alter_table(:variables) do
      drop_index(nil, name: :variable_set_id_variable_name)

      add_column :is_local, TrueClass, :default => true
      add_column :provider_deployment, String, :default => ''

      add_index [:variable_set_id, :variable_name, :provider_deployment], :unique => true, :name => :variable_set_name_provider_idx
    end
  end
end
