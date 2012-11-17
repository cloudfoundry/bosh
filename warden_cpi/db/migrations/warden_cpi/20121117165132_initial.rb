Sequel.migration do
  up do
    create_table? :warden_vm do
      primary_key :id
      String :container_id, :null => false
    end
  end

  down do
    drop_table :warden_vm
  end
end
