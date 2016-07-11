Sequel.migration do
  up do
    create_table :local_dns_records do
      primary_key :id
      String :name, :null => false
      String :ip, :null => false
      foreign_key :instance_id, :instances, :null => false, :on_delete => :cascade
    end

    alter_table :local_dns_records do
      add_index [:name, :ip], unique: true, name: 'name_ip_idx'
    end
  end

  down do
    drop_table :local_dns_records
  end
end

