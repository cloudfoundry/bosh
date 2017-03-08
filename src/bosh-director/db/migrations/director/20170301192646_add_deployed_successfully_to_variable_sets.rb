Sequel.migration do
  up do
    alter_table(:variable_sets) do
      add_column :deployed_successfully, TrueClass, :default => false
    end
  end
end
