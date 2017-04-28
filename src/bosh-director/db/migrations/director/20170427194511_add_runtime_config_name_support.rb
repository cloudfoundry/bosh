Sequel.migration do
  change do
    alter_table(:runtime_configs) do
      add_column :name, String, default: '', null: false
    end
  end
end
