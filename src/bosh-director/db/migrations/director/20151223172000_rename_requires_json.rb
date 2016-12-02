Sequel.migration do
  change do
    alter_table :templates do
      rename_column :requires_json, :consumes_json
    end
  end
end