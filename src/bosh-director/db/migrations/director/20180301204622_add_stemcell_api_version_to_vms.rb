Sequel.migration do
  up do
    alter_table(:vms) do
      add_column :stemcell_api_version, Integer, null: true
    end

    alter_table(:orphaned_vms) do
      add_column :stemcell_api_version, Integer, null: true
    end
  end
end
