Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :availability_zone, String
    end
  end
end
