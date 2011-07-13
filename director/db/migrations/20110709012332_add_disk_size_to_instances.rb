Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :disk_size, Integer
    end
  end
end
