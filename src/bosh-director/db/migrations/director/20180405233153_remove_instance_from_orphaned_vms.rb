Sequel.migration do
  up do
    alter_table(:orphaned_vms) do
      drop_column :instance_id
    end
  end
end
