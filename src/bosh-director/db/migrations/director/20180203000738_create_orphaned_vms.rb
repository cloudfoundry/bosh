Sequel.migration do
  up do
    adapter_scheme = self.adapter_scheme

    alter_table :ip_addresses do
      add_column :orphaned_vm_id, Integer
    end

    create_table :orphaned_vms do |table|
      primary_key :id
      table.String :cid, null: false
      table.Integer :instance_id, null: false
      table.String :availability_zone
      if %i[mysql2 mysql].include?(adapter_scheme)
        table.longtext :cloud_properties
      else
        table.text :cloud_properties
      end
      table.String :cpi
      table.Time :orphaned_at, null: false
    end
  end
end
