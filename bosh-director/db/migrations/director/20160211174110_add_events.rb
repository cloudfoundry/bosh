Sequel.migration do
  up do
    create_table :events do
      primary_key :id
      Integer :parent_id
      String :user, :null => false
      Time :timestamp, :index => true, :null => false
      String :action, :null => false
      String :object_type, :null => false
      String :object_name
      String :error, :text => true
      String :task
      String :deployment
      String :instance
      String :context_json, :text => true
    end
  end

  down do
    drop_table :events
  end
end
