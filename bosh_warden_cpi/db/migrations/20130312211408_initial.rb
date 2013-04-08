Sequel.migration do
  up do
    create_table(:warden_vm) do
      primary_key :id
      String :container_id
    end

    create_table(:warden_disk) do
      primary_key :id
      foreign_key :vm_id, :warden_vm
      Integer :device_num
      String :device_path
      String :image_path
      Boolean :attached, :default => false
    end
  end

  down do
    drop_table :warden_disk
    drop_table :warden_vm
  end
end
