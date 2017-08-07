Sequel.migration do
  change do
    alter_table(:vms) do
      add_column :created_at, Time
    end
  end
end
