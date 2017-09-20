Sequel.migration do
  change do
    create_table :local_dns_encoded_instance_groups do
      primary_key :id
      String :name, null: false
      foreign_key :deployment_id, :deployments, null: false, on_delete: :cascade
      index [:name, :deployment_id], unique: true
    end

    create_table :local_dns_encoded_networks do
      primary_key :id
      String :name, null: false, unique: true
    end

    create_table :local_dns_service_groups do
      primary_key :id
      foreign_key :instance_group_id, :local_dns_encoded_instance_groups, null: false, on_delete: :cascade
      foreign_key :network_id, :local_dns_encoded_networks, null: false
      index [:instance_group_id, :network_id], unique: true
    end
  end
end
