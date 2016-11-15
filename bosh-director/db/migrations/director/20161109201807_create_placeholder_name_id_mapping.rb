Sequel.migration do
  up do
    create_table :placeholder_mappings do
      primary_key :id
      String :placeholder_name, :null => false
      String :placeholder_id, :null => false
      foreign_key :deployment_id, :deployments, :null => false
    end
  end
end