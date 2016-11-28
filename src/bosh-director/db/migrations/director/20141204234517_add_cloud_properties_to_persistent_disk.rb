Sequel.migration do
  change do
    alter_table(:persistent_disks) do
      add_column :cloud_properties_json, String, :text => true
    end
  end
end
