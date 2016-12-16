Sequel.migration do
  change do
    alter_table :tasks do
      add_column :context_id, String, size: 64, default: '', null: false
      add_index :context_id
    end
  end
end
