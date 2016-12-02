Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :availability_zone, String
      add_column :cloud_properties, String, :text => true
    end
  end
end
