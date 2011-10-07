Sequel.migration do
  up do
    create_table(:persistent_disks) do
      primary_key :id
      foreign_key :instance_id, :instances, :null => false
      String :disk_cid, :unique => true, :null => false
      Integer :size
      Boolean :active, :default => false
    end

    self[:instances].each do |instance|
      next unless instance[:disk_cid]

      new_disk_attrs = {
        :disk_cid => instance[:disk_cid],
        :size => instance[:disk_size],
        :instance_id => instance[:id],
        :active => true
      }

      self[:persistent_disks].insert(new_disk_attrs)
    end

    alter_table(:instances) do
      drop_column :disk_cid
      drop_column :disk_size
    end
  end

  down do
    alter_table(:instances) do
      add_column(:disk_size, Integer, :default => 0)
      add_column(:disk_cid, String)
    end

    self[:persistent_disks].each do |disk|
      next unless disk[:active]

      instance_attrs = {
        :disk_cid => disk[:disk_cid],
        :disk_size => disk[:size]
      }

      self[:instances].filter(:id => disk[:instance_id]).update(instance_attrs)
    end

    drop_table(:persistent_disks)
  end
end
