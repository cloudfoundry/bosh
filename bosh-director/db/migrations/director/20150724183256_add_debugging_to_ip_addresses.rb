Sequel.migration do
  change do
    alter_table(:ip_addresses) do
      add_column :created_at, Time
      add_column :task_id, String
    end
  end
end
