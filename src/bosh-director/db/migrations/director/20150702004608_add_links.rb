Sequel.migration do
  change do
    alter_table(:templates) do
      add_column :requires_json, String
      add_column :provides_json, String
    end
  end
end
