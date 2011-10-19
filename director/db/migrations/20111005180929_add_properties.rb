Sequel.migration do
  change do
    create_table :deployment_properties do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false
      String :name, :null => false
      String :value, :null => false

      unique [ :deployment_id, :name ]
    end
  end
end
