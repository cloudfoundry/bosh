Sequel.migration do
  up do
    alter_table :local_dns_encoded_instance_groups do
      add_column :type, String
      drop_index %i[name deployment_id]
      add_index %i[name type deployment_id], unique: true
    end

    self[:local_dns_encoded_instance_groups].update(type: 'instance-group')

    alter_table :local_dns_encoded_instance_groups do
      set_column_not_null :type
    end
  end
end
