Sequel.migration do
  change do
    alter_table :orphan_disks do
      rename_column :orphaned_at, :created_at
    end

    alter_table :orphan_snapshots do
      drop_column :created_at
      rename_column :orphaned_at, :created_at
      add_column :snapshot_created_at, Time
    end
  end
end
