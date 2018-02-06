Sequel.migration do
  up do
    alter_table :ip_addresses do
      add_column :orphaned_vm_id, Integer
    end

    create_table :orphaned_vms do |table|
      primary_key :id
      table.String :cid, null: false
      table.Integer :instance_id, null: false
      table.String :availability_zone
      table.String :cloud_properties, text: true
      table.String :cpi
      table.Time :orphaned_at, null: false
    end
  end
end
