Sequel.migration do
  up do
    create_table :placeholder_name_id_mapping do
      String :placeholder_name, :null => false
      String :placeholder_id, :null => false
      foreign_key :instance_id, :instances, :null => false
      primary_key [:instance_id, :placeholder_name]
    end
  end
end