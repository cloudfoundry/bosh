Sequel.migration do
  change do
    alter_table :instances do
      rename_column :post_start_completed, :update_completed
      set_column_default :update_completed, false
    end
  end
end
