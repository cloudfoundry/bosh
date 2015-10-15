Sequel.migration do
  up do
    create_table(:orphan_disks) do
      primary_key :id
      String :disk_cid, :null => false, :unique => true
      Integer :size
      String :availability_zone
      String :deployment_name, :null => false
      String :instance_name, :null => false
      String :cloud_properties_json, :text => true
      Time :orphaned_at, :null => false, :index => true
    end

    create_table(:orphan_snapshots) do
      primary_key :id
      foreign_key :orphan_disk_id, :orphan_disks, :null => false
      String :snapshot_cid, :unique => true, :null => false
      Boolean :clean, :default => false
      Time :created_at, :null => false
      Time :orphaned_at, :null => false, :index => true
    end
  end

  down do
    drop_table(:orphan_snapshots)
    drop_table(:orphan_disks)
  end
end

