Sequel.migration do
  up do
    create_table :snapshots do
      primary_key :id
      foreign_key :persistent_disk_id, :persistent_disks, :null => false
      TrueClass :clean, default: false
      Time :created_at, :null => false
      String :snapshot_cid, :unique => true, :null => false
    end
  end

  down do
    drop_table :snapshots
  end
end
