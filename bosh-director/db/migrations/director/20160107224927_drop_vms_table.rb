Sequel.migration do
  change do
    # Needed for mysql in order to drop column (doesn't work with other adapters)
    # newer versions of sequel support drop_foreign_key but the version breaks tests
    if [:mysql2, :mysql].include?(adapter_scheme)
      run("alter table instances drop FOREIGN KEY instances_ibfk_2")
    end

    alter_table :instances do
      drop_column :vm_id
    end

    drop_table(:vms)
  end
end
