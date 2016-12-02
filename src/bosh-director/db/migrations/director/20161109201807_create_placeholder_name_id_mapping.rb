Sequel.migration do
  up do
    create_table :placeholder_mappings do
      primary_key :id
      String :placeholder_id, :null => false
      String :placeholder_name, :null => false
      foreign_key :deployment_id, :deployments, :null => false
      unique [:placeholder_id, :deployment_id]
    end
  end
end