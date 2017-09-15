Sequel.migration do
  change do
    db_type =  self.adapter_scheme

    alter_table(:variables) do
      if [:mysql2, :mysql].include?(db_type)
        drop_foreign_key [:variable_set_id]
      end

      drop_index([:variable_set_id, :variable_name], name: :variable_set_id_variable_name)

      if [:mysql2, :mysql].include?(db_type)
        add_foreign_key [:variable_set_id], :variable_sets, :null => false, :on_delete => :cascade
      end

      add_column :is_local, TrueClass, :default => true
      add_column :provider_deployment, String, :default => ''

      add_index [:variable_set_id, :variable_name, :provider_deployment], :unique => true, :name => :variable_set_name_provider_idx
    end
  end
end
