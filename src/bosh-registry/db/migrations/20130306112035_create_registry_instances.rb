Sequel.migration do
  change do
    create_table :registry_instances do
      primary_key :id

      String :instance_id, :null => false, :unique => true
      String :settings, :null => false, :text => true
    end
  end
end