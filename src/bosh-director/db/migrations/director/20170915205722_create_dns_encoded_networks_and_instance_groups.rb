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

    instance_entries_query = self[:instances].
      select(select(:job).as(:name), :deployment_id).
      distinct

    self[:local_dns_encoded_instance_groups].multi_insert instance_entries_query

    network_entries_query = self[:local_dns_records].
      exclude(network: nil).
      select(select(:network).as(:name)).
      distinct

    self[:local_dns_encoded_networks].multi_insert network_entries_query
  end
end
