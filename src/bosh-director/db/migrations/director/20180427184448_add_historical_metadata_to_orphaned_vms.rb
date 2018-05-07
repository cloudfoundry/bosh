Sequel.migration do
  up do
    alter_table(:orphaned_vms) do
      add_column :deployment_name, String
      add_column :instance_name, String
    end
  end
end
