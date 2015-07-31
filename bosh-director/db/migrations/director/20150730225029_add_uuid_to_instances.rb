Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :uuid, String
    end
  end
end
