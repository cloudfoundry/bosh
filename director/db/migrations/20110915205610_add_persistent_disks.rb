$:.unshift(File.expand_path("../../../lib", __FILE__))
require "director"

Sequel.migration do
  up do
    create_table(:persistent_disks) do
      primary_key :id
      foreign_key :instance_id, :instances, :null => false
      String :disk_cid, :unique => true, :null => false
      Integer :size
      Boolean :active, :default => false
    end

    Bosh::Director::Models::Instance.each do |instance|
      next unless instance.disk_cid
      Bosh::Director::Models::PersistentDisk.create(:disk_cid => instance.disk_cid,
                                                    :size => instance.disk_size,
                                                    :instance_id => instance.id,
                                                    :active => true)
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
    Bosh::Director::Models::PersistentDisk.each do |disk|
      next unless disk.active # should we error out instead?
      instance = disk.instance
      instance.disk_cid = disk.disk_cid
      instance.disk_size = disk.size
      instance.save
      disk.destroy
    end
    drop_table(:persistent_disks)
  end
end
