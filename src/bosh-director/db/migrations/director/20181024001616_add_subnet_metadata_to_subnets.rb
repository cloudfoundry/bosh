Sequel.migration do
  up do
    alter_table(:subnets) do
      add_column :predeployment_cloud_properties, String, null: false, default: '{}'
      add_column :type, String, null: false, default: 'range'
      add_column :netmask_bits, Integer, null: true
    end
  end
end
