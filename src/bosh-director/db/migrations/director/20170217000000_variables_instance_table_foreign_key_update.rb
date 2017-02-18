Sequel.migration do
  up do
    alter_table(:instances) do
      drop_foreign_key [:variable_set_id]
      add_foreign_key [:variable_set_id], :variable_sets, :name=>:instance_table_variable_set_fkey
    end
  end
end
