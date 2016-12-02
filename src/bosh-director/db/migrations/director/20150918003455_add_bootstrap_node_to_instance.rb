Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :bootstrap, TrueClass, default: false
    end
  end
end
