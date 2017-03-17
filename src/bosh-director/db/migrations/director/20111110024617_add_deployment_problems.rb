Sequel.migration do
  change do
    create_table :deployment_problems do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false

      String :state, :null => false

      Integer :resource_id, :null => false
      String :type, :null => false
      String :data_json, :text => true, :null => false

      Time :created_at, :null => false
      Time :last_seen_at, :null => false

      Integer :counter, :null => false, :default => 0

      index [:deployment_id, :type, :state]
      index [:deployment_id, :state, :created_at]
    end
  end
end
