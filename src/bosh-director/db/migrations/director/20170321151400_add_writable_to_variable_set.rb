Sequel.migration do
  change do
    alter_table(:variable_sets) do
      add_column :writable, TrueClass, :default => false
    end
  end
end
