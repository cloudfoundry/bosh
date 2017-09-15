Sequel.migration do
  change do
    alter_table(:templates) do
      add_column :properties_json, String, :text => true
    end
  end
end
