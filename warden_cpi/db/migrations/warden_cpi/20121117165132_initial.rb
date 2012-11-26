Sequel.migration do
  up do
    create_table? :warden_vm do
      primary_key :id
      String :container_id, :null => false
    end

    create_table? :warden_disk do
      primary_key :id
      Integer :device_num
      String :device_path
      String :image_path
      Boolean :attached, :default => false
    end
  end

  down do
    drop_table :warden_vm
    drop_table :warden_disk
  end
end
