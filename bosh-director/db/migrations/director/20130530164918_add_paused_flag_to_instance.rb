Sequel.migration do
  up do
    alter_table :instances do
      add_column :resurrection_paused, TrueClass
      set_column_default :resurrection_paused, false
    end
  end

  down do
    alter_table :instances do
      drop_column :resurrection_paused
    end
  end
end
