# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table(:instances) do
      add_column :disk_size, Integer
    end
  end
end
