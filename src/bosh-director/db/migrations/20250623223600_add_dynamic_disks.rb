Sequel.migration do
  up do
    case adapter_scheme
    when :postgres
      create_table(:dynamic_disks) do
        primary_key :id
        foreign_key :deployment_id, :deployments, :null => false, :key => [:id]
        foreign_key :vm_id, :vms, :key => [:id], :on_delete => :set_null
        column :disk_cid, 'varchar(255)', :null => false
        column :disk_hint_json, 'varchar(255)'
        column :name, 'varchar(255)', :null => false
        column :disk_pool_name, 'varchar(255)', :null => false
        column :cpi, 'varchar(255)', :default => ''
        column :size, 'integer', :null => false
        column :metadata_json, 'text'
        column :availability_zone, 'varchar(255)'
        index [:name], :unique => true
      end
    when :mysql2
      create_table(:dynamic_disks) do
        primary_key :id
        foreign_key :deployment_id, :deployments, :null => false, :key => [:id]
        foreign_key :vm_id, :vms, :key => [:id], :on_delete => :set_null
        column :disk_cid, 'varchar(255)', :null => false
        column :disk_hint_json, 'varchar(255)'
        column :name, 'varchar(255)', :null => false
        column :disk_pool_name, 'varchar(255)', :null => false
        column :cpi, 'varchar(255)', :default => ''
        column :size, 'integer', :null => false
        column :metadata_json, 'longtext'
        column :availability_zone, 'varchar(255)'
        index [:name], :unique => true
      end
    when :sqlite
      create_table(:dynamic_disks) do
        primary_key :id
        foreign_key :deployment_id, :deployments, :null => false, :key => [:id]
        foreign_key :vm_id, :vms, :key => [:id], :on_delete => :set_null
        column :disk_cid, 'varchar(255)', :null => false
        column :disk_hint_json, 'varchar(255)'
        column :name, 'varchar(255)', :null => false
        column :disk_pool_name, 'varchar(255)', :null => false
        column :cpi, 'varchar(255)', :default => ''
        column :size, 'integer', :null => false
        column :metadata_json, 'TEXT'
        column :availability_zone, 'varchar(255)'
        index [:name], :unique => true
      end
    else
      raise "Unknown adapter_scheme: #{adapter_scheme}"
    end
  end

  down do
    delete_table(:dynamic_disks)
  end
end
