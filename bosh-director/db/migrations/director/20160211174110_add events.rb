Sequel.migration do
  up do
    create_table :events do
      primary_key :id
      String :target_type, :null => false
      String :target_name
      String :event_action, :null => false
      String :event_state, :null => false
      String :event_result, :text => true
      Integer :task_id, :null => false
      Time :timestamp, :null => false
    end
  end
end
