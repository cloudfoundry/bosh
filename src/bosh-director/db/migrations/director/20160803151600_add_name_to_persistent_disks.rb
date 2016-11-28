Sequel.migration do
  change do
    alter_table(:persistent_disks) do
      add_column(:name, String, default: '')
    end
  end
end
