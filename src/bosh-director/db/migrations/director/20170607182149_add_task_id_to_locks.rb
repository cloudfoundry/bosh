Sequel.migration do
  change do
    alter_table(:locks) do
      add_column :task_id, String, default: '', null: false
    end
  end
end
