Sequel.migration do
  change do
    alter_table(:instances) do
      drop_column :vm_id
    end

    drop_table(:vms)
  end
end
