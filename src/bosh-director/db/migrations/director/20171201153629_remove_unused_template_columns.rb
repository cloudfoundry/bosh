Sequel.migration do
  up do
    alter_table(:templates) do
      drop_column :provides_json
      drop_column :consumes_json
      drop_column :properties_json
      drop_column :logs_json
      drop_column :templates_json
    end
  end
end
