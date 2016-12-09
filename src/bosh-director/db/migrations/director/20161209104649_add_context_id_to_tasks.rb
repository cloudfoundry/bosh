Sequel.migration do
  change do
    alter_table :tasks do
      add_column :context_id, String, default: '', null: false
    end
  end
end
