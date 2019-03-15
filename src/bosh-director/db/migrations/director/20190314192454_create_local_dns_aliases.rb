Sequel.migration do
  up do
    create_table :local_dns_aliases do
      primary_key :id
      foreign_key :deployment_id, :deployments, on_delete: :cascade

      String :domain
      String :target
    end
  end
end
