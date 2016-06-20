Sequel.migration do
  change do
    drop_table(:events)

    create_table :events do
      Time :id, :index => true, unique: true, primary_key: true, :null => false
      Time :parent_id
      String :user, :null => false
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
end
