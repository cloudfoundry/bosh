Sequel.migration do
  up do
    create_table? :vsphere_disk do
      primary_key :id
      String :path, :null => true
      String :datacenter, :null => true
      String :datastore, :null => true
      Integer :size, :null => false
    end
  end

  down do
    drop_table :vsphere_disk
  end
end