Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :compilation, TrueClass, default: false
    end
  end
end
