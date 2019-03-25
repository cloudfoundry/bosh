Sequel.migration do
  up do
    alter_table(:instances) do
      drop_column :resurrection_paused
    end
  end
end
