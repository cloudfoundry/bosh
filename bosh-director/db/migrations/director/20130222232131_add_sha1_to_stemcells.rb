# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table(:stemcells) do
      add_column :sha1, String
    end
  end
end