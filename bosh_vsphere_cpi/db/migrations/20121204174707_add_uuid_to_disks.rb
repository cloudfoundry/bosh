# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  up do
    add_column :vsphere_disk, :uuid, String
    self[:vsphere_disk].update(:uuid => :id)
    add_index :vsphere_disk, :uuid, :unique => true
  end

  down do
    drop_index :vsphere_disk, :uuid, :unique => true
    drop_column :vsphere_disk, :uuid
  end
end
