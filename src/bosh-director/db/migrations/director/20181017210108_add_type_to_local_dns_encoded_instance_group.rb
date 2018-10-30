Sequel.migration do
  up do
    alter_table :local_dns_encoded_instance_groups do
      add_column :type, String, null: false, default: 'instance-group'
      drop_index %i[name deployment_id]
      add_index %i[name type deployment_id], unique: true
      set_column_default :type, 'instance-group'
    end
  end
end
