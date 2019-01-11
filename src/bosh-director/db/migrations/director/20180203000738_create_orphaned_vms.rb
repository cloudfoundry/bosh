Sequel.migration do
  up do
    adapter_scheme = self.adapter_scheme

    alter_table :ip_addresses do
      add_column :orphaned_vm_id, Integer
    end

    create_table :orphaned_vms do
      primary_key :id
      String :cid, null: false
      Integer :instance_id, null: false
      String :availability_zone
      if %i[mysql2 mysql].include?(adapter_scheme)
        longtext :cloud_properties
      else
        text :cloud_properties
      end
      String :cpi
      Time :orphaned_at, null: false
    end
  end
end
