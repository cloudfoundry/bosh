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

  end
end
